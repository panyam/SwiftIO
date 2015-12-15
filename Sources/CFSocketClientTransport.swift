//
//  CFSocketClientTransport.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/14/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

let DEFAULT_BUFFER_SIZE = 8192
public class CFSocketClientTransport : ClientTransport {
    var clientSocket : CFSocketNativeHandle
    var connection : Connection?
    var readStream : CFReadStream?
    var writeStream : CFWriteStream?
    
    init(_ clientSock : CFSocketNativeHandle) {
        clientSocket = clientSock;
        withUnsafeMutablePointer(&readStream) {
            let readStreamPtr = UnsafeMutablePointer<Unmanaged<CFReadStream>?>($0)
            withUnsafeMutablePointer(&writeStream, {
                let writeStreamPtr = UnsafeMutablePointer<Unmanaged<CFWriteStream>?>($0)
                CFStreamCreatePairWithSocket(kCFAllocatorDefault, clientSocket, readStreamPtr, writeStreamPtr)
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
                    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
                }
            }
            
            clearWriteable()
            
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
    
    /**
     * Called to initiate consuming of the write buffers to send data down the connection.
     */
    func setWriteable() {
        let writeEvents = CFStreamEventType.CanAcceptBytes.rawValue | CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
        self.registerWriteEvents(writeEvents)
    }
    
    private func clearWriteable() {
        let writeEvents = CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
        self.registerWriteEvents(writeEvents)
    }
    
    private func registerWriteEvents(events: CFOptionFlags) {
        var streamClientContext = CFStreamClientContext(version:0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
        withUnsafePointer(&streamClientContext) {
            if (CFWriteStreamSetClient(writeStream, events, writeCallback, UnsafeMutablePointer<CFStreamClientContext>($0)))
            {
                CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
            }
        }
    }
    
    var readBuffer = UnsafeMutablePointer<UInt8>.alloc(DEFAULT_BUFFER_SIZE)
    
    func connectionClosed() {
        connection?.connectionClosed()
    }
    
    func hasBytesAvailable() {
        // It is safe to call CFReadStreamRead; it won’t block because bytes are available.
        let bytesRead = CFReadStreamRead(readStream, readBuffer, DEFAULT_BUFFER_SIZE);
        if bytesRead > 0 {
            connection?.dataReceived(readBuffer, length: bytesRead)
        } else if bytesRead < 0 {
            handleReadError()
        }
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
            }
            return
        }
        
        // no more bytes so clear writeable
        clearWriteable()
    }
    
    func handleReadError() {
        let error = CFReadStreamGetError(readStream);
        print("Read error: \(error)")
        CFReadStreamUnscheduleFromRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    }
    
    func handleWriteError() {
        let error = CFWriteStreamGetError(writeStream);
        print("Write error: \(error)")
        CFWriteStreamUnscheduleFromRunLoop(writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    }
}

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
