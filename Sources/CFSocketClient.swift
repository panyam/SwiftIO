
//
//  CFSocketClient.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/14/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation
import Darwin

public class CFSocketClient : Stream, DataSender, DataReceiver {
    public var consumer : StreamConsumer?
    public var producer : StreamProducer?
    var clientSocketNative : CFSocketNativeHandle
    var clientSocket : CFSocket?
    var streamRunLoop : RunLoop
    public var runLoop : RunLoop {
        return streamRunLoop
    }
    var READER_HANDLES_READS = true
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
        if readsAreEdgeTriggered || true {
            streamRunLoop.enqueue {
//                self.hasBytesAvailable()
            }
        }
    }
    
    /**
     * Indicates to the stream that no writes are required as yet and to not invoke the write callback
     * until explicitly required again.
     */
    public func clearReadyToWrite() {
        disableSocketFlag(kCFSocketAutomaticallyReenableWriteCallBack)
    }
    
    /**
     * Indicates to the stream that no writes are required as yet and to not invoke the write callback
     * until explicitly required again.
     */
    public func clearReadyToRead() {
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
        var sock_opt_on = Int32(1)
        setsockopt(clientSocketNative, SOL_SOCKET, SO_NOSIGPIPE, &sock_opt_on, socklen_t(sizeofValue(sock_opt_on)))
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
            if !CFSocketIsValid(clientSocket)
            {
                handleWriteError(EPIPE)
            }
            else
            {
                let hasMoreData = consumer.canReceiveData(self)
                if hasMoreData
                {
                    if readsAreEdgeTriggered {
                        self.runLoop.enqueue {
                            self.hasBytesAvailable()
                        }
                    }
                    return
                }
            }
        }
        clearReadyToRead()
    }
    
    /**
     * Reads upto a length number of bytes into the provided buffer.
     * Returns:
     *  A tuple of number of bytes and any errors:
     *  +ve,null    =>  A successful read of at least 1 byte and no error
     *  -1,error    =>  Error in the read along with the actual error.
     *  0,nil       =>  No more data available (possibly for now).
     */
    public func read(buffer: ReadBufferType, length: LengthType) -> (LengthType, ErrorType?)
    {
        let numRead = recv(clientSocketNative, buffer, length, MSG_DONTWAIT)
        if numRead > 0 {
            return (numRead, nil)
        } else if numRead < 0 && errno != EAGAIN {
            // error?
            return (numRead, SocketErrorType(domain: "POSIX", code: errno, message: "Socket read error"))
        } else if numRead == 0 {
            // socket closed
            return (0, IOErrorType.Closed)
        } else {
            Log.debug("0 bytes read")
            return (0, nil)
        }
    }
    
    public func write(buffer: WriteBufferType, length: LengthType) -> (LengthType, ErrorType?)
    {
        let numWritten = send(clientSocketNative, buffer, length, MSG_DONTWAIT)
        if numWritten > 0 {
            return (numWritten, nil)
        } else if numWritten < 0 {
            // error?
            return (numWritten, SocketErrorType(domain: "POSIX", code: errno, message: "Socket write error"))
        } else {
            Log.debug("0 bytes sent")
            return (0, nil)
        }
    }
    
    func canAcceptBytes() {
        if let producer = self.producer
        {
            if !CFSocketIsValid(clientSocket)
            {
                handleWriteError(EPIPE)
            }
            else
            {
                let (hasMoreData, error) = producer.canSendData(self)
                if hasMoreData && error == nil
                {
                    if writesAreEdgeTriggered {
                        self.runLoop.enqueue {
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
