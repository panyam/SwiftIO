//
//  BufferedStream.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/18/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public typealias ConsumerCallback = (buffer: BufferType, length: Int, error: ErrorType?) -> (bytesConsumed: Int, finished: Bool, error: ErrorType?)

/**
 * Keeps track of the reed request "call tree" indiciating where and how 
 * data read from the stream should be delivered to.
 */
private class ConsumerFrame
{
    weak var parentFrame : ConsumerFrame?
    var callback : ConsumerCallback?
    var callbackCalled = false
    var bytesConsumed = 0
    var finished = false
    var error : ErrorType? = nil
    var children = [ConsumerFrame]()
    init(_ callback: ConsumerCallback?)
    {
        self.callback = callback
    }
    
    func addConsumer(consumer: ConsumerCallback)
    {
        let newFrame = ConsumerFrame(consumer)
        newFrame.parentFrame = self
        children.append(newFrame)
        children.append(newFrame)
    }
    
    func removeIfFinished()
    {
        if finished {
            // Now no new frames were added *and* the current frame had finished
            // so remove it from its parents child list
            assert(self === parentFrame?.children.first, "Frame MUST be parent's first frame")
            parentFrame?.children.removeFirst()
        }
    }
    
    var firstFrame : ConsumerFrame? {
        get { return children.first }
    }
}

public class BufferedReader : Reader {
    private var reader : Reader
    private var dataBuffer : BufferType
    private var bufferSize : Int = 0
    private var startOffset : Int = 0
    private var endOffset : Int = 0
    private var rootFrame = ConsumerFrame(nil)
    private var frameStack = [ConsumerFrame]()
    
    public var bytesAvailable : Int {
        get {
            let out = endOffset - startOffset
            return max(out, 0)
        }
    }

    public init (reader: Reader, bufferSize: Int)
    {
        self.reader = reader
        self.bufferSize = bufferSize
        self.dataBuffer = BufferType.alloc(bufferSize)
        frameStack.append(rootFrame)
    }
    
    public func close()
    {
    }

    public func read(buffer: BufferType, length: Int, callback: IOCallback)
    {
        let readLength = length
        // Simple consumer that takes what ever data is returned
        consumeTill { (buffer, length, error) -> (bytesConsumed: Int, finished: Bool, error: ErrorType?) in
            callback(buffer: buffer, length: length, error: error)
            return (min(readLength, length), true, error)
        }
    }
    
    /**
     * Read till a particular character is encountered (including the delimiter).
     */
    public func readTillChar(delimiter: UInt8, callback : (str : String, error: ErrorType?) -> ())
    {
        var returnedString = ""
        consumeTill { (buffer, length, error) -> (bytesConsumed: Int, finished: Bool, error: ErrorType?) in
            if error != nil {
                callback(str: returnedString, error: error)
                return (0, false, error)
            }
            
            var bytesConsumed = 0
            var finished = false
            for currOffset in 0..<length {
                bytesConsumed++
                let currChar = buffer[currOffset]
                if currChar == delimiter {
                    finished = true
                    callback(str: returnedString, error: nil)
                    break
                } else {
                    returnedString.append(Character(UnicodeScalar(currChar)))
                }
            }
            return (bytesConsumed, finished, nil)
        }
    }
    
    /**
     * This is a generic method to ensure that data can be consumed till a certain criteria is 
     * met (as decided by the caller) and then any data that is not used after this point is 
     * left intact for the next reader.
     *
     * This can be used as a base for other readXXXX type methods.
     *
     * Some requirements are:
     * 1. Flexibility - A simple consumer callback should be used to denote how
     *    far "reads" should happen without forcing any restrictions upon them.
     * 2. composable: It should be possible for a consumer processor callback itself
     *    to initiate another consume method and all reads should go to *that* method first
     *    and satisfy the requirements of that consumer before the caller consumer is given
     *    any data.
     * 3. Error handling: Errors should be propogatable along the call chain.
     *
     * If this sounds like promises - it almost is because:
     * 1. Promises are not the foundation here but rather callbacks are, so
     * 2. Promises can be used/built ontop of these callbacks.
     * 3. Readers are sequantial streams.  So composability over parallelism is a key requirement.
     * 
     */
    public func consumeTill(consumer: ConsumerCallback)
    {
        produceBytesForConsumer(consumer, lastError: nil)
    }
    
    private func produceBytesForConsumer(c : ConsumerCallback?, lastError: ErrorType?)
    {
        if let newConsumer = c
        {
            frameStack.last?.addConsumer(newConsumer)
        } else if let error = lastError {
            unwindWithError(error)
            return
        }
        
        // find the next frame that can consume data
        
        // ensure this happens in reader's runloop
        // if we have data in the buffer, pass that to the consumer
        if bytesAvailable > 0 {
            // there is data available so give it to the candidate callback
            if var frame = frameStack.last {
                // TODO: cache this so that we wont have to compute this each time
                while frame.firstFrame != nil {
                    frame = frame.firstFrame!
                }
            
                // before calling the callback, add the current frame onto the stack
                // this ensures that any calls to consumeTill made from within this frame
                // will be added to this frame's child list so we preserve the required
                // depth first ordering.
                frameStack.append(frame)
                frame.callbackCalled = true
                let (bytesConsumed, finished, error) = frame.callback!(buffer: dataBuffer.advancedBy(startOffset), length: bytesAvailable, error: lastError)
                
                assert(bytesConsumed > 0, "At least one byte must be consumed")
                assert(bytesConsumed < bytesAvailable, "How can you consume more bytes than is available?")
                
                startOffset += bytesConsumed
                if startOffset >= endOffset {
                    startOffset = 0
                    endOffset = 0
                }
                
                frame.bytesConsumed += bytesConsumed
                frame.finished = finished
                frame.error = error
                
                while frameStack.last! === frame && frame !== rootFrame {
                    // if no new frames were added then this can be removed
                    frame.callbackCalled = false
                    frameStack.removeLast()

                    // also remove it from the parent
                    let parentFrame = frame.parentFrame!
                    frame.removeIfFinished()
                    frame = parentFrame
                }
                
                // continue consuming bytes for any other consumers we may have left
                produceBytesForConsumer(nil, lastError: error)
            }
        } else {
            // need to do a read
            startOffset = 0
            endOffset = 0
            reader.read(dataBuffer, length: bufferSize, callback: { (buffer, length, error) -> () in
                if error == nil {
                    self.endOffset = length
                }
                // call read again so that data in the buffer is returned
                self.produceBytesForConsumer(nil, lastError: error)
            })
        }
    }
    
    private func unwindWithError(error: ErrorType)
    {
        assert(false, "Not yet implemented")
    }
}