//
//  BufferedStream.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/18/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class DataBuffer
{
    private var bufferSize : Int
    private var buffer : BufferType
    private var startOffset : Int = 0
    private var endOffset : Int = 0
    
    public var capacity : Int {
        return bufferSize
    }
    
    public var length : Int {
        get {
            let out = endOffset - startOffset
            return max(out, 0)
        }
    }
    

    public init(_ bufferSize: Int)
    {
        self.bufferSize = bufferSize
        self.buffer = BufferType.alloc(bufferSize)
    }
    
    public func reset()
    {
        startOffset = 0
        endOffset = 0
    }

    /**
     * Advance the stream position by a given number of bytes.
     * This will be used by the consumer callback to continually update its status.
     */
    func advance(bytesConsumed: Int)
    {
        startOffset = min(startOffset + bytesConsumed, endOffset)
    }
    
    /**
     * Return the buffer of the stream beginning at the current position.
     */
    var current : BufferType {
        return buffer.advancedBy(startOffset)
    }
    
    subscript(index: Int) -> UInt8 {
        get {
            return buffer[startOffset + index]
        }
    }
    
    public func read(reader: Reader, callback: IOCallback?)
    {
        if startOffset == endOffset
        {
            startOffset = 0
            endOffset = 0
        }

        // TODO: see if needs resizing or moving or circular management
        assert(bufferSize > endOffset, "Needs some work here!")
        reader.read(current, length: bufferSize - endOffset) { (buffer, length, error) -> () in
            if error == nil {
                self.endOffset += length
            }
            callback?(buffer: buffer, length: length, error: error)
        }
    }
}

public typealias ConsumerCallback = (buffer: DataBuffer, error: ErrorType?) -> (finished: Bool, error: ErrorType?)
public typealias CompletionCallback = (bytesConsumed: Int, error: ErrorType?) -> ()

/**
 * Keeps track of the reed request "call tree" indiciating where and how 
 * data read from the stream should be delivered to.
 */
private class ConsumerFrame
{
    weak var parentFrame : ConsumerFrame?
    var callback : ConsumerCallback?
    var callbackCalled = false
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
    }
    
    func removeIfFinished()
    {
        if finished && children.isEmpty {
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
    private var dataBuffer : DataBuffer
    private var bufferSize : Int = 0
    private var rootFrame = ConsumerFrame(nil)
    private var frameStack = [ConsumerFrame]()
    
    public init (reader: Reader, bufferSize: Int)
    {
        self.reader = reader
        self.bufferSize = bufferSize
        self.dataBuffer = DataBuffer(bufferSize)
        frameStack.append(rootFrame)
    }

    /**
     * Initiate a read for at least one byte.
     */
    public func read(buffer: BufferType, length: Int, callback: IOCallback?)
    {
        let readBuffer = buffer
        let readLength = length

        // Simple consumer that takes what ever data is returned
        consume { (buffer, error) -> (finished: Bool, error: ErrorType?) in
            // copy from buffer to readBuffer
            readBuffer.assignFrom(buffer.current, count: min(readLength, length))
            buffer.advance(min(readLength, length))
            
            callback?(buffer: readBuffer, length: min(readLength, length), error: error)
            return (true, error)
        }
    }
    
    /**
     * Initiate a read for a given size and waits till all the bytes have been returned.
     */
    public func readFully(buffer: BufferType, length: Int, callback: IOCallback?)
    {
        let readBuffer = buffer
        var totalConsumed = 0
        let totalRemaining = length

        // Simple consumer that takes what ever data is returned
        consume { (buffer, error) -> (finished: Bool, error: ErrorType?) in
            if error != nil {
                callback?(buffer: readBuffer, length: totalConsumed, error: error)
                return (false, error)
            }
            
            let remaining = totalRemaining - totalConsumed
            let nCopied = min(remaining, length)
            readBuffer.advancedBy(totalConsumed).assignFrom(buffer.current, count: nCopied)
            buffer.advance(nCopied)

            totalConsumed += nCopied
            let finished = totalConsumed >= totalRemaining
            if finished {
                callback?(buffer: readBuffer, length: totalConsumed, error: nil)
            }
            return (finished, nil)
        }
    }

    /**
     * Read till a particular character is encountered (not including the delimiter).
     */
    public func readTillChar(delimiter: UInt8, callback : ((str : String, error: ErrorType?) -> ())?)
    {
        var returnedString = ""
        consume { (buffer, error) -> (finished: Bool, error: ErrorType?) in
            if error != nil {
                callback?(str: returnedString, error: error)
                return (false, error)
            }
            
            var finished = false
            let length = buffer.length
            for _ in 0..<length {
                let currChar = buffer[0]
                buffer.advance(1)
                
                if currChar == delimiter {
                    finished = true
                    callback?(str: returnedString, error: nil)
                    break
                } else {
                    returnedString.append(Character(UnicodeScalar(currChar)))
                }
            }
            return (finished, nil)
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
    public func consume(consumer: ConsumerCallback)
    {
        produceBytesForConsumer(consumer, lastError: nil)
    }
    
    private func produceBytesForConsumer(c : ConsumerCallback?, lastError: ErrorType?)
    {
        if let newConsumer = c
        {
            frameStack.last!.addConsumer(newConsumer)
//            if frameStack.last!.callbackCalled {
//                // if callback of the parent was being called then let it complete before
//                // handling its children otherwise we will keep adding children without
//                // advancing the startOffset of any data that may have been read
//                return
//            }
        } else if let error = lastError {
            unwindWithError(error)
            return
        }
        
        // find the next frame that can consume data
        
        // ensure this happens in reader's runloop
        // if we have data in the buffer, pass that to the consumer
        if dataBuffer.length > 0 {
            // there is data available so give it to the candidate callback
            if var currFrame = frameStack.last {
                // TODO: cache this so that we wont have to compute this each time
                while currFrame.firstFrame != nil {
                    currFrame = currFrame.firstFrame!
                }
            
                // before calling the callback, add the current frame onto the stack
                // this ensures that any calls to consume made from within this frame
                // will be added to this frame's child list so we preserve the required
                // depth first ordering.
                frameStack.append(currFrame)
                currFrame.callbackCalled = true
                let (finished, error) = currFrame.callback!(buffer: dataBuffer, error: lastError)
                
//                currFrame.bytesConsumed += bytesConsumed
                currFrame.finished = finished
                currFrame.error = error
                
                while frameStack.last! === currFrame && currFrame !== rootFrame {
                    // if no new frames were added then this can be removed
                    currFrame.callbackCalled = false
                    frameStack.removeLast()

                    // also remove it from the parent
                    let parentFrame = currFrame.parentFrame!
                    currFrame.removeIfFinished()
                    currFrame = parentFrame
                }
                
                // continue consuming bytes for any other consumers we may have left
                CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopCommonModes, { () -> Void in
                    self.produceBytesForConsumer(nil, lastError: error)
                })
                CFRunLoopWakeUp(CFRunLoopGetCurrent())
            }
        } else {
            // need to do a read
            dataBuffer.read(reader, callback: { (buffer, length, error) -> () in
                self.produceBytesForConsumer(nil, lastError: error)
            })
        }
    }
    
    private func unwindWithError(error: ErrorType)
    {
        assert(false, "Not yet implemented")
    }
}