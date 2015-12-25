
//
//  CFSocketClient.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/14/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public func DefaultRunLoop() -> RunLoop
{
    return CoreFoundationRunLoop.defaultInstance
}

public func CurrentRunLoop() -> RunLoop
{
    return CoreFoundationRunLoop.defaultInstance
}

public class CoreFoundationRunLoop : RunLoop
{
    static let defaultInstance = CoreFoundationRunLoop(CFRunLoopGetMain())
    var cfRunLoop : CFRunLoop

    /**
     * Gets the current runloop
     */
    public static func defaultRunLoop() -> RunLoop
    {
        return defaultInstance
    }
    
    /**
     * Gets the current runloop
     */
    public static func currentRunLoop() -> RunLoop
    {
        return CoreFoundationRunLoop(CFRunLoopGetCurrent())
    }
    
    public init(_ loop : CFRunLoop?)
    {
        if let theLoop = loop {
            cfRunLoop = theLoop
        } else {
            cfRunLoop = CFRunLoopGetCurrent()
        }
    }

    /**
     * Starts the runloop
     */
    public func start()
    {
        while CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
        }
    }
    
    /**
     * Stops the runloop
     */
    public func stop()
    {
        CFRunLoopStop(cfRunLoop)
    }
    
    /**
     * Ensures that the block is performed within the runloop (if not already happening)
     */
    public func ensure(block: () -> Void)
    {
        let currRunLoop = CFRunLoopGetCurrent()
        if cfRunLoop === currRunLoop {
            block()
        } else {
            enqueue(block)
        }
    }
    
    /**
     * Enqueues a block to be run on the runloop.
     */
    public func enqueue(block: () -> Void)
    {
        CFRunLoopPerformBlock(cfRunLoop, kCFRunLoopCommonModes, block)
        CFRunLoopWakeUp(cfRunLoop)
    }
}

public class CFStream : Stream
{
    public var runLoop : RunLoop
    public var consumer : StreamConsumer?
    public var producer : StreamProducer?
    var readStream : CFReadStream?
    var readsAreEdgeTriggered = false
    
    var writeStream : CFWriteStream?
    var writesAreEdgeTriggered = true

    var cfRunLoop : CFRunLoop {
        return (runLoop as! CoreFoundationRunLoop).cfRunLoop
    }

    public init(_ loop: CFRunLoop?) {
        self.runLoop = CoreFoundationRunLoop(loop)
    }
    
    private func asUnsafeMutableVoid() -> UnsafeMutablePointer<Void>
    {
        let selfAsOpaque = Unmanaged<CFStream>.passUnretained(self).toOpaque()
        let selfAsVoidPtr = UnsafeMutablePointer<Void>(selfAsOpaque)
        return selfAsVoidPtr
    }
    
    public func setReadStream(stream : CFReadStream)
    {
        if self.readStream !== stream
        {
            var streamClientContext = CFStreamClientContext(version:0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
            let readEvents = CFStreamEventType.HasBytesAvailable.rawValue | CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
            withUnsafePointer(&streamClientContext) {
                if readStream != nil {
                    CFReadStreamSetClient(readStream, readEvents, nil, UnsafeMutablePointer<CFStreamClientContext>($0))
                    CFReadStreamUnscheduleFromRunLoop(readStream, cfRunLoop, kCFRunLoopCommonModes)
                }
                self.readStream = stream
                CFReadStreamSetClient(readStream, readEvents, streamReadCallback, UnsafeMutablePointer<CFStreamClientContext>($0))
                CFReadStreamScheduleWithRunLoop(readStream, cfRunLoop, kCFRunLoopCommonModes);
            }
            setReadyToRead()
        }
    }

    /**
     * Called to close the stream.
     */
    public func close() {
        if readStream != nil
        {
            CFReadStreamUnscheduleFromRunLoop(readStream, cfRunLoop, kCFRunLoopCommonModes);
        }
        if writeStream != nil
        {
            CFWriteStreamUnscheduleFromRunLoop(writeStream, cfRunLoop, kCFRunLoopCommonModes);
        }
    }
    
    /**
     * Called to indicate that the connection is ready to read data
     */
    public func setReadyToRead() {
        let readEvents = CFStreamEventType.HasBytesAvailable.rawValue | CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
        self.registerReadEvents(readEvents)
        
        // Should this be called here?
        // It is possible that a client can call this as many as
        // time as it needs greedily
        if readsAreEdgeTriggered {
            self.runLoop.enqueue { () -> Void in
                self.hasBytesAvailable()
            }
        }
    }
    
    /**
     * Indicates to the stream that no reads are required as yet and to not invoke the read callback
     * until explicitly required again.
     */
    private func clearReadyToRead() {
        let readEvents = CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
        self.registerReadEvents(readEvents)
    }
    
    private func registerReadEvents(events: CFOptionFlags) {
        if readStream != nil {
            var streamClientContext = CFStreamClientContext(version:0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
            withUnsafePointer(&streamClientContext) {
                if (CFReadStreamSetClient(readStream, events, streamReadCallback, UnsafeMutablePointer<CFStreamClientContext>($0)))
                {
                    CFReadStreamUnscheduleFromRunLoop(readStream, cfRunLoop, kCFRunLoopCommonModes)
                    CFReadStreamScheduleWithRunLoop(readStream, cfRunLoop, kCFRunLoopCommonModes);
                }
            }
        }
    }
    
    func hasBytesAvailable() {
        // It is safe to call CFReadStreamRead; it won’t block because bytes are available.
        if let consumer = self.consumer
        {
            if let (buffer, length) = consumer.readDataRequested() {
                if length > 0 {
                    let bytesRead = CFReadStreamRead(readStream, buffer, length);
                    if bytesRead > 0 {
                        consumer.dataReceived(bytesRead)
                    } else if bytesRead < 0 {
                        handleReadError()
                    } else {
                        // peer has closed so should we finish?
                        clearReadyToRead()
                        close()
                    }
                    return
                }
            }
        }
        clearReadyToRead()
    }
    
    func handleReadError() {
        let error = CFReadStreamGetError(readStream);
        print("Read error: \(error)")
        if let consumer = self.consumer
        {
            consumer.receivedReadError(SocketErrorType(domain: (error.domain as NSNumber).stringValue, code: error.error, message: ""))
        }
        close()
    }
    
    func streamClosed() {
        assert(false, "not yet implemented")
        //        stream?.connectionClosed()
    }
    
    public func setWriteStream(stream : CFWriteStream)
    {
        if self.writeStream !== stream
        {
            var streamClientContext = CFStreamClientContext(version:0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
            let writeEvents = CFStreamEventType.CanAcceptBytes.rawValue | CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
            withUnsafePointer(&streamClientContext) {
                if writeStream != nil {
                    CFWriteStreamSetClient(writeStream, writeEvents, nil, UnsafeMutablePointer<CFStreamClientContext>($0))
                    CFWriteStreamUnscheduleFromRunLoop(writeStream, cfRunLoop, kCFRunLoopCommonModes)
                }
                self.writeStream = stream
                CFWriteStreamSetClient(writeStream, writeEvents, streamWriteCallback, UnsafeMutablePointer<CFStreamClientContext>($0))
                CFWriteStreamScheduleWithRunLoop(writeStream, cfRunLoop, kCFRunLoopCommonModes);
            }
            setReadyToWrite()
        }
    }
    
    /**
     * Called to indicate that the connection is ready to write data
     */
    public func setReadyToWrite() {
        let writeEvents = CFStreamEventType.CanAcceptBytes.rawValue | CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
        self.registerWriteEvents(writeEvents)
        
        // Should this be called here?
        // It is possible that a client can call this as many as
        // time as it needs greedily
        if writesAreEdgeTriggered {
            self.runLoop.enqueue { () -> Void in
                self.canAcceptBytes()
            }
        }
    }
    
    /**
     * Indicates to the stream that no writes are required as yet and to not invoke the write callback
     * until explicitly required again.
     */
    private func clearReadyToWrite() {
        let writeEvents = CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
        self.registerWriteEvents(writeEvents)
    }
    
    private func registerWriteEvents(events: CFOptionFlags) {
        if writeStream != nil {
            var streamClientContext = CFStreamClientContext(version:0, info: asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
            withUnsafePointer(&streamClientContext) {
                if (CFWriteStreamSetClient(writeStream, events, streamWriteCallback, UnsafeMutablePointer<CFStreamClientContext>($0)))
                {
                    CFWriteStreamUnscheduleFromRunLoop(writeStream, cfRunLoop, kCFRunLoopCommonModes)
                    CFWriteStreamScheduleWithRunLoop(writeStream, cfRunLoop, kCFRunLoopCommonModes);
                }
            }
        }
    }
    
    func canAcceptBytes() {
        if let producer = self.producer
        {
            if let (buffer, length) = producer.writeDataRequested() {
                if length > 0 {
                    let numWritten = CFWriteStreamWrite(writeStream, buffer, length)
                    if numWritten > 0 {
                        producer.dataWritten(numWritten)
                    } else if numWritten < 0 {
                        // error?
                        handleWriteError()
                    } else {
                        print("0 bytes sent")
                    }
                    
                    if numWritten >= 0 && numWritten < length {
                        // only partial data written so dont clear writeable.
                        // if this is the case then for an edge triggered API
                        // we have to ensure that canAcceptBytes will eventually
                        // get called.  So kick it off later on.
                        // TODO: ensure that we have some kind of backoff so that
                        // these async triggers dont flood the run loop if the write
                        // stream is backed
                        if writesAreEdgeTriggered {
                            self.runLoop.enqueue { () -> Void in
                                self.canAcceptBytes()
                            }
                        }
                        return
                    }
                }
            }
        }
        
        // no more bytes so clear writeable
        clearReadyToWrite()
    }
    
    func handleWriteError() {
        let error = CFWriteStreamGetError(writeStream);
        print("Write error: \(error)")
        if let producer = self.producer
        {
            producer.receivedWriteError(SocketErrorType(domain: (error.domain as NSNumber).stringValue, code: error.error, message: ""))
        }
        close()
    }
}

/**
 * Callback for the read stream when data is available or errored.
 */
func streamReadCallback(readStream: CFReadStream!, eventType: CFStreamEventType, info: UnsafeMutablePointer<Void>) -> Void
{
    let stream = Unmanaged<CFStream>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
    if eventType == CFStreamEventType.HasBytesAvailable {
        stream.hasBytesAvailable()
    } else if eventType == CFStreamEventType.EndEncountered {
        stream.streamClosed()
    } else if eventType == CFStreamEventType.ErrorOccurred {
        stream.handleReadError()
    }
}

/**
 * Callback for the write stream when data is available or errored.
 */
func streamWriteCallback(writeStream: CFWriteStream!, eventType: CFStreamEventType, info: UnsafeMutablePointer<Void>) -> Void
{
    let stream = Unmanaged<CFStream>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
    if eventType == CFStreamEventType.CanAcceptBytes {
        stream.canAcceptBytes();
    } else if eventType == CFStreamEventType.EndEncountered {
        stream.streamClosed()
    } else if eventType == CFStreamEventType.ErrorOccurred {
        stream.handleWriteError()
    }
}
