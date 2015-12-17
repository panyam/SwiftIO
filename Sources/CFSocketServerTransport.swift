//
// This source file is part of the Swiftli open source http2.0 server project
//
// Copyright (c) 2015-2016 Sriram Panyam
// Licensed under Apache License v2.0 with Runtime Library Exception
//
//
//===----------------------------------------------------------------------===//
//
//  This file implements a client transport and runloop on top of CFSocketNativeHandle.
//
//===----------------------------------------------------------------------===//

import Foundation
import Darwin
//
//#if os(Linux)
//    import SwiftGlibc
//#endif

let DEFAULT_SERVER_PORT : UInt16 = 9999

private func handleConnectionAccept(socket: CFSocket!,
    callbackType: CFSocketCallBackType,
    address: CFData!,
    data: UnsafePointer<Void>,
    info: UnsafeMutablePointer<Void>)
{
    if (callbackType == CFSocketCallBackType.AcceptCallBack)
    {
        let socketTransport = Unmanaged<CFSocketServerTransport>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
        let clientSocket = UnsafePointer<CFSocketNativeHandle>(data)
        let clientSocketNativeHandle = clientSocket[0]
        socketTransport.handleConnection(clientSocketNativeHandle);
    }
}

public class CFSocketServerTransport : ServerTransport
{
    /**
     * Option to ignore a request if header's exceed this length>
     */
    private var isRunning = false
    private var stopped = false
    public var serverPort : UInt16 = DEFAULT_SERVER_PORT
    public var serverPortV6 : UInt16 = DEFAULT_SERVER_PORT
    private var serverSocket : CFSocket?
    private var serverSocketV6 : CFSocket?
    public var connectionFactory : ConnectionFactory?
    private var transportRunLoop : CFRunLoop
    
    public init(var _ runLoop : CFRunLoop?)
    {
        if runLoop == nil
        {
            runLoop = CFRunLoopGetCurrent();
        }
        transportRunLoop = runLoop!
    }
    
    public func start() -> SocketErrorType?
    {
        if isRunning {
            NSLog("Server is already running")
            return nil
        }
        
        NSLog("Registered server")
        isRunning = true
        return initSocket()
    }
    
    public func stop() {
    }

    func handleConnection(clientSocketNativeHandle : CFSocketNativeHandle)
    {
        if var connection = connectionFactory?.connectionAccepted()
        {
            let clientTransport = CFSocketClientTransport(clientSocketNativeHandle, runLoop: transportRunLoop)
            connection.transport = clientTransport
            clientTransport.connection = connection
        } else {
            // TODO: close the socket since no connection delegate was found
        }
    }

    private func initSocket() -> SocketErrorType?
    {
        let selfAsOpaque = Unmanaged<CFSocketServerTransport>.passUnretained(self).toOpaque()
        let selfAsVoidPtr = UnsafeMutablePointer<Void>(selfAsOpaque)
        var socketContext = CFSocketContext(version: 0, info: selfAsVoidPtr, retain: nil, release: nil, copyDescription: nil)
        withUnsafePointer(&socketContext) {
            serverSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, 0, 0, 2, handleConnectionAccept, UnsafePointer<CFSocketContext>($0));
        }

        var sin = sockaddr_in();
        sin.sin_len = UInt8(sizeof(sockaddr_in));
        sin.sin_family = sa_family_t(AF_INET);
        sin.sin_port = UInt16(serverPort).bigEndian
        sin.sin_addr.s_addr = 0
        let sin_len = sizeof(sockaddr_in)
        
        var error : SocketErrorType? = nil
        withUnsafePointer(&sin) { //(<#UnsafePointer<T>#>) -> Result in
            let sincfd = CFDataCreate(
                kCFAllocatorDefault,
                UnsafePointer($0),
                sin_len);
            let err = CFSocketSetAddress(serverSocket, sincfd);
            if err != CFSocketError.Success {
                error = SocketErrorType(message: "Unable to set address on socket")
                let errstr : String? =  String.fromCString(strerror(errno));
                NSLog ("Socket Set Address Error: \(err.rawValue), \(errno), \(errstr)")
            }
        }

        if error == nil {
            let socketSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, serverSocket, 0)
            CFRunLoopAddSource(transportRunLoop, socketSource, kCFRunLoopDefaultMode)
        }
        return error
    }

    private func asUnsafeMutableVoid() -> UnsafeMutablePointer<Void>
    {
        let selfAsOpaque = Unmanaged<CFSocketServerTransport>.passUnretained(self).toOpaque()
        let selfAsVoidPtr = UnsafeMutablePointer<Void>(selfAsOpaque)
        return selfAsVoidPtr
    }
    
    private func initSocketV6() -> SocketErrorType?
    {
        var socketContext = CFSocketContext(version: 0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
        withUnsafePointer(&socketContext) {
            serverSocketV6 = CFSocketCreate(kCFAllocatorDefault, PF_INET6, 0, 0, 2, handleConnectionAccept, UnsafePointer<CFSocketContext>($0));
        }
        
        // Bind v6 socket
        var sin6 = sockaddr_in6();
        sin6.sin6_len = UInt8(sizeof(sockaddr_in6));
        sin6.sin6_family = sa_family_t(AF_INET6);
        sin6.sin6_port = UInt16(serverPortV6).bigEndian
        sin6.sin6_addr = in6addr_any;
        let sin6_len = sizeof(sockaddr_in)
        
        var error : SocketErrorType? = nil
        withUnsafePointer(&sin6) { //(<#UnsafePointer<T>#>) -> Result in
            let sincfd = CFDataCreate(
                kCFAllocatorDefault,
                UnsafePointer($0),
                sin6_len);
            
            let err = CFSocketSetAddress(serverSocketV6, sincfd)
            if err != CFSocketError.Success {
                let errstr : String? =  String.fromCString(strerror(errno));
                error = SocketErrorType(message: "Unable to set V6 address on socket")
                NSLog ("Socket Set Address Error: \(err.rawValue), \(errno), \(errstr)")
            }
        }

        if error == nil {
            let socketSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, serverSocketV6, 0)
            CFRunLoopAddSource(transportRunLoop, socketSource, kCFRunLoopDefaultMode)
        }
        return error
    }
}

