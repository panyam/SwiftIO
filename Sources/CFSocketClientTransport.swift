//
//  CFSocketClientTransport.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/14/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation


public class CFSocketClientTransport : ClientTransport {
    var connection : Connection?
    var clientSocketNative : CFSocketNativeHandle
    var readStream : CFReadStream?
    var writeStream : CFWriteStream?
    var transportRunLoop : CFRunLoop
    var readsAreEdgeTriggered = true
    var writesAreEdgeTriggered = true
    
    init(_ clientSock : CFSocketNativeHandle, runLoop: CFRunLoop?) {
        clientSocketNative = clientSock;
        if let theLoop = runLoop {
            transportRunLoop = theLoop
        } else {
            transportRunLoop = runLoop!
        }
        initStreams();
        setReadyToWrite()
        setReadyToRead()
    }
    
    /**
     * Perform an action in run loop corresponding to this client transport.
     */
    public func performBlock(block: (() -> Void))
    {
//        let currRunLoop = CFRunLoopGetCurrent()
//        if transportRunLoop == currRunLoop {
//            block()
//        } else {
            CFRunLoopPerformBlock(transportRunLoop, kCFRunLoopCommonModes, block)
//        }
    }

    /**
     * Called to close the transport.
     */
    public func close() {
        CFReadStreamUnscheduleFromRunLoop(readStream, transportRunLoop, kCFRunLoopCommonModes);
        CFWriteStreamUnscheduleFromRunLoop(writeStream, transportRunLoop, kCFRunLoopCommonModes);
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
            CFRunLoopPerformBlock(transportRunLoop, kCFRunLoopCommonModes) { () -> Void in
                self.canAcceptBytes()
            }
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
            CFRunLoopPerformBlock(transportRunLoop, kCFRunLoopCommonModes) { () -> Void in
                self.hasBytesAvailable()
            }
        }
    }
    
    /**
     * Indicates to the transport that no writes are required as yet and to not invoke the write callback
     * until explicitly required again.
     */
    private func clearReadyToWrite() {
        let writeEvents = CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
        self.registerWriteEvents(writeEvents)
    }
    
    /**
     * Indicates to the transport that no writes are required as yet and to not invoke the write callback
     * until explicitly required again.
     */
    private func clearReadbale() {
        let readEvents = CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
        self.registerReadEvents(readEvents)
    }
    
    private func initStreams()
    {
        withUnsafeMutablePointer(&readStream) {
            let readStreamPtr = UnsafeMutablePointer<Unmanaged<CFReadStream>?>($0)
            withUnsafeMutablePointer(&writeStream, {
                let writeStreamPtr = UnsafeMutablePointer<Unmanaged<CFWriteStream>?>($0)
                CFStreamCreatePairWithSocket(kCFAllocatorDefault, clientSocketNative, readStreamPtr, writeStreamPtr)
            })
        }
        
        if readStream != nil && writeStream != nil {
            CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            
            // register with run loop
            var streamClientContext = CFStreamClientContext(version:0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
            let readEvents = CFStreamEventType.HasBytesAvailable.rawValue | CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
            withUnsafePointer(&streamClientContext) {
                if (CFReadStreamSetClient(readStream, readEvents, readCallback, UnsafeMutablePointer<CFStreamClientContext>($0)))
                {
                    CFReadStreamScheduleWithRunLoop(readStream, transportRunLoop, kCFRunLoopCommonModes);
                }
            }
            
            if CFReadStreamOpen(readStream) && CFWriteStreamOpen(writeStream) {
                //use the streams
                print("Streams initialized")
            }
            else {
                print("Could not initialize streams!");
            }
        }
        
        // set its read/write/close events on the runloop
    }

    private func asUnsafeMutableVoid() -> UnsafeMutablePointer<Void>
    {
        let selfAsOpaque = Unmanaged<CFSocketClientTransport>.passUnretained(self).toOpaque()
        let selfAsVoidPtr = UnsafeMutablePointer<Void>(selfAsOpaque)
        return selfAsVoidPtr
    }

    func start(delegate : Connection) {
        connection = delegate
    }
    
    func connectionClosed() {
        connection?.connectionClosed()
    }
    
    func hasBytesAvailable() {
        // It is safe to call CFReadStreamRead; it won’t block because bytes are available.
        if let (buffer, length) = connection?.readDataRequested() {
            if length > 0 {
                let bytesRead = CFReadStreamRead(readStream, buffer, length);
                if bytesRead > 0 {
                    connection?.dataReceived(bytesRead)
                } else if bytesRead < 0 {
                    handleReadError()
                }
                return
            }
        }
//        clearReadyToRead()
    }
    
    func canAcceptBytes() {
        if let (buffer, length) = connection?.writeDataRequested() {
            if length > 0 {
                let numWritten = CFWriteStreamWrite(writeStream, buffer, length)
                if numWritten > 0 {
                    connection?.dataWritten(numWritten)
                } else if numWritten < 0 {
                    // error?
                    handleWriteError()
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
                        CFRunLoopPerformBlock(transportRunLoop, kCFRunLoopCommonModes) {
                            self.canAcceptBytes()
                        }
                    }
                    return
                }
            }
        }
        
        // no more bytes so clear writeable
        clearReadyToWrite()
    }
    
    func handleReadError() {
        let error = CFReadStreamGetError(readStream);
        print("Read error: \(error)")
        connection?.receivedReadError(SocketErrorType(domain: (error.domain as NSNumber).stringValue, code: Int(error.error), message: ""))
        close()
    }
    
    func handleWriteError() {
        let error = CFWriteStreamGetError(writeStream);
        print("Write error: \(error)")
        connection?.receivedWriteError(SocketErrorType(domain: (error.domain as NSNumber).stringValue, code: Int(error.error), message: ""))
        close()
    }
    
    private func registerWriteEvents(events: CFOptionFlags) {
        if writeStream != nil {
            var streamClientContext = CFStreamClientContext(version:0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
            withUnsafePointer(&streamClientContext) {
                if (CFWriteStreamSetClient(writeStream, events, writeCallback, UnsafeMutablePointer<CFStreamClientContext>($0)))
                {
                    CFWriteStreamScheduleWithRunLoop(writeStream, transportRunLoop, kCFRunLoopCommonModes);
                }
            }
        }
    }
    
    private func registerReadEvents(events: CFOptionFlags) {
        if readStream != nil {
            var streamClientContext = CFStreamClientContext(version:0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
            withUnsafePointer(&streamClientContext) {
                if (CFReadStreamSetClient(readStream, events, readCallback, UnsafeMutablePointer<CFStreamClientContext>($0)))
                {
                    CFReadStreamScheduleWithRunLoop(readStream, transportRunLoop, kCFRunLoopCommonModes);
                }
            }
        }
    }
}

/**
 * Callback for the read stream when data is available or errored.
 */
func readCallback(readStream: CFReadStream!, eventType: CFStreamEventType, info: UnsafeMutablePointer<Void>) -> Void
{
    let socketConnection = Unmanaged<CFSocketClientTransport>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
    if eventType == CFStreamEventType.HasBytesAvailable {
        socketConnection.hasBytesAvailable()
    } else if eventType == CFStreamEventType.EndEncountered {
        socketConnection.connectionClosed()
    } else if eventType == CFStreamEventType.ErrorOccurred {
        socketConnection.handleReadError()
    }
}

/**
 * Callback for the write stream when data is available or errored.
 */
func writeCallback(writeStream: CFWriteStream!, eventType: CFStreamEventType, info: UnsafeMutablePointer<Void>) -> Void
{
    let socketConnection = Unmanaged<CFSocketClientTransport>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
    if eventType == CFStreamEventType.CanAcceptBytes {
        socketConnection.canAcceptBytes();
    } else if eventType == CFStreamEventType.EndEncountered {
        socketConnection.connectionClosed()
    } else if eventType == CFStreamEventType.ErrorOccurred {
        socketConnection.handleWriteError()
    }
}
