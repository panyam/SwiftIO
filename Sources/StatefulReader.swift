//
//  StatefulReader.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/30/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class StatefulReader : Reader
{
    public typealias ConsumerCallback = (reader: Reader) -> (finished: Bool, error: ErrorType?)
    public typealias ErrorCallback = (error : ErrorType) -> ErrorType?

    private var reader : Reader
    private var rootFrame = ConsumerFrame(nil, nil)
    private var frameStack = [ConsumerFrame]()
    
    public init (_ reader: Reader, bufferSize: Int)
    {
        self.reader = reader
        frameStack.append(rootFrame)
    }
    
    public convenience init (_ reader: Reader)
    {
        self.init(reader, bufferSize: DEFAULT_BUFFER_LENGTH)
    }
    
    public var bytesAvailable : Int {
        get {
            return reader.bytesAvailable
        }
    }
    
    public func read() -> (value: UInt8, error: ErrorType?) {
        return reader.read()
    }

    /**
     * Initiate a read for at least one byte.
     */
    public func read(buffer: ReadBufferType, length: Int, callback: IOCallback?)
    {
        let readBuffer = buffer
        let readLength = length
        
        // Simple consumer that takes what ever data is returned
        self.consume({ (reader) -> (finished: Bool, error: ErrorType?) in
            // copy from buffer to readBuffer
            reader.read(readBuffer, length: min(readLength, reader.bytesAvailable), callback: nil)
            callback?(length: min(readLength, length), error: nil)
            return (true, nil)
        }, onError: {(error : ErrorType) -> ErrorType? in
            callback?(length: min(readLength, length), error: nil)
            return error
        })
    }
    
    /**
     * Initiate a read for a given size and waits till all the bytes have been returned.
     */
    public func readFully(buffer: ReadBufferType, length: Int, callback: IOCallback?)
    {
        let readBuffer = buffer
        var totalConsumed = 0
        let totalRemaining = length
        
        // Simple consumer that takes what ever data is returned
        consume({ (reader) -> (finished: Bool, error: ErrorType?) in
            let remaining = totalRemaining - totalConsumed
            let nCopied = min(remaining, reader.bytesAvailable)
            reader.read(readBuffer.advancedBy(totalConsumed), length: nCopied, callback: nil)
            
            totalConsumed += nCopied
            let finished = totalConsumed >= totalRemaining
            if finished {
                callback?(length: totalConsumed, error: nil)
            }
            return (finished, nil)
        }, onError: {(error: ErrorType) -> ErrorType? in
            callback?(length: totalConsumed, error: error)
            return error
        })
    }
    
    /**
     * Read till a particular character is encountered (not including the delimiter).
     */
    public func readTillChar(delimiter: UInt8, callback : ((str : String, error: ErrorType?) -> ())?)
    {
        var returnedString = ""
        consume({ (reader) -> (finished: Bool, error: ErrorType?) in
            var finished = false
            while reader.bytesAvailable > 0
            {
                let (currChar, _) = reader.read()
            
                if currChar == delimiter {
                    finished = true
                    callback?(str: returnedString, error: nil)
                    break
                } else {
                    returnedString.append(Character(UnicodeScalar(currChar)))
                }
            }
            return (finished, nil)
        }, onError: {(error: ErrorType) -> ErrorType? in
            callback?(str: returnedString, error: error)
            return error
        })
    }
    
    public func readNBytes(numBytes : Int, bigEndian: Bool, callback : ((value : Int64, error: ErrorType?) -> Void)?)
    {
        var numBytesLeft = numBytes
        var output : Int64 = 0
        consume({(reader) -> (finished: Bool, error: ErrorType?) in
            let length = min(numBytesLeft, reader.bytesAvailable)
            if bigEndian {
                for _ in 0..<length
                {
                    let (nextByte, _) = reader.read()
                    output = (output << 8) | Int64(Int8(bitPattern: nextByte))
                    numBytesLeft--
                }
            } else {
                
            }
            if numBytesLeft == 0
            {
                callback?(value: output, error: nil)
                return (true, nil)
            } else {
                return (false, nil)
            }
        }, onError: {(error: ErrorType) -> ErrorType? in
            callback?(value: 0, error: error)
            return error
        })
    }
    
    public func readInt8(callback : ((value : Int8, error : ErrorType?) -> Void)?)
    {
        return readNBytes(1, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: Int8(truncatingBitPattern: (value & 0x00000000000000ff)), error: nil)
        })
    }
    
    public func readInt16(callback : ((value : Int16, error : ErrorType?) -> Void)?)
    {
        return readNBytes(2, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: Int16(truncatingBitPattern: (value & 0x000000000000ffff)), error: nil)
        })
    }
    
    public func readInt32(callback : ((value : Int32, error : ErrorType?) -> Void)?)
    {
        return readNBytes(4, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: Int32(truncatingBitPattern: (value & 0x00000000ffffffff)), error: nil)
        })
    }
    
    public func readInt64(callback : ((value : Int64, error : ErrorType?) -> Void)?)
    {
        return readNBytes(8, bigEndian: true, callback: callback)
    }
    
    public func readUInt8(callback : ((value : UInt8, error : ErrorType?) -> Void)?)
    {
        return readNBytes(1, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: UInt8(truncatingBitPattern: (value & 0x00000000000000ff)), error: nil)
        })
    }
    
    public func readUInt16(callback : ((value : UInt16, error : ErrorType?) -> Void)?)
    {
        return readNBytes(2, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: UInt16(truncatingBitPattern: (value & 0x000000000000ffff)), error: nil)
        })
    }
    
    public func readUInt32(callback : ((value : UInt32, error : ErrorType?) -> Void)?)
    {
        return readNBytes(4, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: UInt32(truncatingBitPattern: (value & 0x00000000ffffffff)), error: nil)
        })
    }
    
    public func readUInt64(callback : ((value : UInt64, error : ErrorType?) -> Void)?)
    {
        let origCallback = callback
        return readNBytes(8, bigEndian: true, callback: { (value, error) -> Void in
            origCallback?(value: UInt64(value), error: error)
        })
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
        self.consume(consumer, onError: nil)
    }
    
    public func consume(consumer: ConsumerCallback, onError: ErrorCallback?)
    {
        produceBytesForConsumer(consumer, onError: onError, lastError: nil)
    }
    
    private func produceBytesForConsumer(c : ConsumerCallback?, onError: ErrorCallback?, lastError: ErrorType?)
    {
        if let consumerCallback = c
        {
            frameStack.last!.addConsumer(ConsumerFrame(consumerCallback, onError))
            //            if frameStack.last!.callbackCalled {
            //                // if callback of the parent was being called then let it complete before
            //                // handling its children otherwise we will keep adding children without
            //                // advancing the startOffset of any data that may have been read
            //                return
            //            }
        }
        else if let error = lastError
        {
            unwindWithError(error)
            return
        }
        
        // find the next frame that can consume data
        
        // ensure this happens in reader's runloop
        // if we have data in the buffer, pass that to the consumer
        if reader.bytesAvailable > 0 {
            // there is data available so give it to the candidate callback
            if var topFrame = frameStack.last
            {
                while topFrame.firstFrame != nil {
                    topFrame = topFrame.firstFrame!
                }
                
                // pop off finished frames
                var finalFrame : ConsumerFrame? = topFrame
                while finalFrame != nil && finalFrame?.finished == true
                {
                    let parentFrame = finalFrame?.parentFrame!
                    finalFrame?.removeIfFinished()
                    finalFrame = parentFrame
                    while finalFrame?.firstFrame != nil
                    {
                        finalFrame = finalFrame?.firstFrame
                    }
                }
                
                if finalFrame === rootFrame
                {
                    return
                }
                
                if var currFrame = finalFrame {
                    // before calling the callback, add the current frame onto the stack
                    // this ensures that any calls to consume made from within this frame
                    // will be added to this frame's child list so we preserve the required
                    // depth first ordering.
                    frameStack.append(currFrame)
                    currFrame.callbackCalled = true
                    let (finished, error) = currFrame.callback!(reader: reader)
                    
                    currFrame.finished = finished
                    currFrame.error = error
                    
                    while frameStack.last! === currFrame && currFrame !== rootFrame
                    {
                        // if no new frames were added then this can be removed
                        currFrame.callbackCalled = false
                        frameStack.removeLast()
                        
                        // also remove it from the parent
                        let parentFrame = currFrame.parentFrame!
                        currFrame.removeIfFinished()
                        currFrame = parentFrame
                    }
                    
                    // continue consuming bytes for any other consumers we may have left
                    self.produceBytesForConsumer(nil, onError: onError, lastError: error)
                }
            }
        } else {
            // need to do a read
            reader.read(nil, length: 1, callback: { (length, error) -> () in
                self.produceBytesForConsumer(nil, onError: nil, lastError: error)
            })
        }
    }
    
    private func unwindWithError(error: ErrorType)
    {
        if var topFrame = frameStack.last
        {
            while topFrame.firstFrame != nil {
                topFrame = topFrame.firstFrame!
            }
            
            var currError : ErrorType? = error
            // pop off finished frames
            var finalFrame : ConsumerFrame? = topFrame
            while frameStack.count > 1 || frameStack[0].children.isEmpty && currError != nil {
                let parentFrame = finalFrame?.parentFrame!
                if let errorCallback = finalFrame?.errorCallback {
                    currError = errorCallback(error: currError!)
                }
                finalFrame?.finished = true
                finalFrame?.removeIfFinished()
                finalFrame = parentFrame
                while finalFrame?.firstFrame != nil
                {
                    finalFrame = finalFrame?.firstFrame
                }
            }
        }
    }
}

/**
 * Keeps track of the reed request "call tree" indiciating where and how
 * data read from the stream should be delivered to.
 */
private class ConsumerFrame
{
    weak var parentFrame : ConsumerFrame?
    var callback : StatefulReader.ConsumerCallback?
    var errorCallback : StatefulReader.ErrorCallback?
    var callbackCalled = false
    var finished = false
    var error : ErrorType? = nil
    var children = [ConsumerFrame]()
    
    init(_ callback: StatefulReader.ConsumerCallback?, _ errorCallback: StatefulReader.ErrorCallback?)
    {
        self.callback = callback
        self.errorCallback = errorCallback
    }
    
    func addConsumer(newFrame: ConsumerFrame)
    {
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
