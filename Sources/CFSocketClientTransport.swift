
//
//  CFSocketClientTransport.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/14/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation
import Darwin

public class CFSocketClientTransport : ClientTransport {
    var connection : Connection?
    var clientSocketNative : CFSocketNativeHandle
    var clientSocket : CFSocket?
    var transportRunLoop : CFRunLoop
    var readsAreEdgeTriggered = false
    var writesAreEdgeTriggered = true
    var runLoopSource : CFRunLoopSource?
    
    init(_ clientSock : CFSocketNativeHandle, runLoop: CFRunLoop?) {
        clientSocketNative = clientSock;
        if let theLoop = runLoop {
            transportRunLoop = theLoop
        } else {
            transportRunLoop = runLoop!
        }

        initSockets();
        
        enableSocketFlag(kCFSocketCloseOnInvalidate)
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
        CFRunLoopRemoveSource(transportRunLoop, runLoopSource, kCFRunLoopCommonModes)
    }
    
    /**
     * Called to indicate that the connection is ready to write data
     */
    public func setReadyToWrite() {
        enableSocketFlag(kCFSocketAutomaticallyReenableWriteCallBack)
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
        enableSocketFlag(kCFSocketAutomaticallyReenableReadCallBack)
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
        disableSocketFlag(kCFSocketAutomaticallyReenableWriteCallBack)
    }
    
    /**
     * Indicates to the transport that no writes are required as yet and to not invoke the write callback
     * until explicitly required again.
     */
    private func clearReadyToRead() {
        disableSocketFlag(kCFSocketAutomaticallyReenableReadCallBack)
    }
    
    private func initSockets()
    {
        // mark the socket as non blocking first
        var socketContext = CFSocketContext(version: 0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
        withUnsafePointer(&socketContext) {
            clientSocket = CFSocketCreateWithNative(kCFAllocatorDefault,
                clientSocketNative,
                CFSocketCallBackType.ReadCallBack.rawValue | CFSocketCallBackType.WriteCallBack.rawValue,
                clientSocketCallback,
                UnsafePointer<CFSocketContext>($0))
        }
        runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, clientSocket, 0)
        CFRunLoopAddSource(transportRunLoop, runLoopSource, kCFRunLoopDefaultMode)
    }

    private func asUnsafeMutableVoid() -> UnsafeMutablePointer<Void>
    {
        let selfAsOpaque = Unmanaged<CFSocketClientTransport>.passUnretained(self).toOpaque()
        let selfAsVoidPtr = UnsafeMutablePointer<Void>(selfAsOpaque)
        return selfAsVoidPtr
    }
    
    func connectionClosed() {
        connection?.connectionClosed()
    }
    
    func hasBytesAvailable() {
        // It is safe to call CFReadStreamRead; it won’t block because bytes are available.
        if let (buffer, length) = connection?.readDataRequested() {
            if length > 0 {
                let bytesRead = recv(clientSocketNative, buffer, length, 0)
                if bytesRead > 0 {
                    connection?.dataReceived(bytesRead)
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
        clearReadyToRead()
    }
    
    func canAcceptBytes() {
        if let (buffer, length) = connection?.writeDataRequested() {
            if length > 0 {
                let numWritten = send(clientSocketNative, buffer, length, 0)
                if numWritten > 0 {
                    connection?.dataWritten(numWritten)
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
//        let error = CFReadStreamGetError(readStream);
//        print("Read error: \(error)")
//        connection?.receivedReadError(SocketErrorType(domain: (error.domain as NSNumber).stringValue, code: Int(error.error), message: ""))
        close()
    }
    
    func handleWriteError() {
//        let error = CFWriteStreamGetError(writeStream);
//        print("Write error: \(error)")
//        connection?.receivedWriteError(SocketErrorType(domain: (error.domain as NSNumber).stringValue, code: Int(error.error), message: ""))
        close()
    }
    
    func enableSocketFlag(flag: UInt) {
        var flags = CFSocketGetSocketFlags(clientSocket)
        flags |= flag
        CFSocketSetSocketFlags(clientSocket, flags)
    }

    func disableSocketFlag(flag: UInt) {
        var flags = CFSocketGetSocketFlags(clientSocket)
        flags &= ~flag
        CFSocketSetSocketFlags(clientSocket, flags)
    }
}

private func clientSocketCallback(socket: CFSocket!,
    callbackType: CFSocketCallBackType,
    address: CFData!,
    data: UnsafePointer<Void>,
    info: UnsafeMutablePointer<Void>)
{
    if (callbackType == CFSocketCallBackType.ReadCallBack)
    {
        let clientTransport = Unmanaged<CFSocketClientTransport>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
        clientTransport.hasBytesAvailable()
    }
    else if (callbackType == CFSocketCallBackType.WriteCallBack)
    {
        print("Write callback")
        let clientTransport = Unmanaged<CFSocketClientTransport>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
        clientTransport.canAcceptBytes()
    }
}
