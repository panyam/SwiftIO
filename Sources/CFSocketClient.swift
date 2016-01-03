
//
//  CFSocketClient.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/14/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation
import Darwin

public class CFSocketClient : Stream {
    public var consumer : StreamConsumer?
    public var producer : StreamProducer?
    var clientSocketNative : CFSocketNativeHandle
    var clientSocket : CFSocket?
    var streamRunLoop : RunLoop
    public var runLoop : RunLoop {
        return streamRunLoop
    }
    var readsAreEdgeTriggered = false
    var writesAreEdgeTriggered = true
    var runLoopSource : CFRunLoopSource?
    
    init(_ clientSock : CFSocketNativeHandle, runLoop: CFRunLoop?) {
        clientSocketNative = clientSock;
        
        streamRunLoop = CoreFoundationRunLoop(runLoop)

        initSockets();
        
        enableSocketFlag(kCFSocketCloseOnInvalidate)
        setReadyToWrite()
        setReadyToRead()
    }

    var cfRunLoop : CFRunLoop {
        return (streamRunLoop as! CoreFoundationRunLoop).cfRunLoop
    }

    /**
     * Called to close the streamRunLoop.
     */
    public func close() {
        CFSocketInvalidate(clientSocket)
        CFRunLoopRemoveSource(cfRunLoop, runLoopSource, kCFRunLoopCommonModes)
        consumer?.streamClosed()
        producer?.streamClosed()
    }
    
    /**
     * Called to indicate that the socket is ready to write data
     */
    public func setReadyToWrite() {
        enableSocketFlag(kCFSocketAutomaticallyReenableWriteCallBack)
        // Should this be called here?
        // It is possible that a client can call this as many as
        // time as it needs greedily
        if writesAreEdgeTriggered {
            streamRunLoop.enqueue {
                self.canAcceptBytes()
            }
        }
    }
    
    /**
     * Called to indicate that the socket is ready to read data
     */
    public func setReadyToRead() {
        enableSocketFlag(kCFSocketAutomaticallyReenableReadCallBack)
        // Should this be called here?
        // It is possible that a client can call this as many as
        // time as it needs greedily
        if readsAreEdgeTriggered {
            streamRunLoop.enqueue {
                self.hasBytesAvailable()
            }
        }
    }
    
    /**
     * Indicates to the stream that no writes are required as yet and to not invoke the write callback
     * until explicitly required again.
     */
    private func clearReadyToWrite() {
        disableSocketFlag(kCFSocketAutomaticallyReenableWriteCallBack)
    }
    
    /**
     * Indicates to the stream that no writes are required as yet and to not invoke the write callback
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
        CFRunLoopAddSource(cfRunLoop, runLoopSource, kCFRunLoopDefaultMode)
    }

    private func asUnsafeMutableVoid() -> UnsafeMutablePointer<Void>
    {
        let selfAsOpaque = Unmanaged<CFSocketClient>.passUnretained(self).toOpaque()
        let selfAsVoidPtr = UnsafeMutablePointer<Void>(selfAsOpaque)
        return selfAsVoidPtr
    }
    
    func connectionClosed() {
        assert(false, "Not yet implemented")
//        stream?.connectionClosed()
    }
    
    func hasBytesAvailable() {
        // It is safe to call recv; it won’t block because bytes are available.
        if let consumer = self.consumer
        {
            if let (buffer, length) = consumer.readDataRequested() {
                if length > 0 {
                    let bytesRead = recv(clientSocketNative, buffer, length, 0)
                    if bytesRead > 0 {
                        consumer.dataReceived(bytesRead)
                    } else if bytesRead < 0 {
                        handleReadError(errno)
                    } else {
                        // peer has closed so should we finish?
                        consumer.dataReceived(bytesRead)
                        clearReadyToRead()
                        close()
                    }
                    return
                }
            }
        }
        clearReadyToRead()
    }
    
    func canAcceptBytes() {
        if let producer = self.producer
        {
            if let (buffer, length) = producer.writeDataRequested() {
                if length > 0 {
                    let numWritten = send(clientSocketNative, buffer, length, 0)
                    if numWritten > 0 {
                        producer.dataWritten(numWritten)
                    } else if numWritten < 0 {
                        // error?
                        handleWriteError(errno)
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
                            self.runLoop.enqueue {
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
    
    func handleReadError(errorCode: Int32) {
        if let consumer = self.consumer
        {
            consumer.receivedReadError(SocketErrorType(domain: "POSIX", code: errorCode, message: "Socket read error"))
        }
        close()
    }
    
    func handleWriteError(errorCode: Int32) {
        if let producer = self.producer
        {
            producer.receivedWriteError(SocketErrorType(domain: "POSIX", code: errorCode, message: "Socket write error"))
        }
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
        let clientTransport = Unmanaged<CFSocketClient>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
        clientTransport.hasBytesAvailable()
    }
    else if (callbackType == CFSocketCallBackType.WriteCallBack)
    {
        let clientTransport = Unmanaged<CFSocketClient>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
        clientTransport.canAcceptBytes()
    }
}
