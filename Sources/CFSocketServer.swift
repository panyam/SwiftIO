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
        let socketTransport = Unmanaged<CFSocketServer>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
        let clientSocket = UnsafePointer<CFSocketNativeHandle>(data)
        let clientSocketNativeHandle = clientSocket[0]
        socketTransport.handleConnection(clientSocketNativeHandle);
    }
}

public class CFSocketServer : StreamServer
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
    public var streamFactory : StreamFactory?
    private var transportRunLoop : CFRunLoop
    
    public init(var _ runLoop : CFRunLoop?)
    {
        if runLoop == nil
        {
            runLoop = CFRunLoopGetCurrent();
        }
        transportRunLoop = runLoop!
    }
    
    public func start() -> ErrorType?
    {
        if isRunning {
            NSLog("Server is already running")
            return nil
        }
        
        NSLog("Registered server")
        isRunning = true
        if let error = initSocket() {
            return error
        }
//        if let error = initSocketV6() {
//            return error
//        }
        return nil
    }
    
    public func stop() {
        CFSocketInvalidate(serverSocket)
    }

    func handleConnection(clientSocketNativeHandle : CFSocketNativeHandle)
    {
        let clientStream = CFSocketClient(clientSocketNativeHandle, runLoop: transportRunLoop)
        streamFactory?.streamStarted(clientStream)
    }
    
    private func initSocket() -> SocketErrorType?
    {
        let (socket, error) = createSocket(serverPort, isV6: false)
        serverSocket = socket
        return error
    }
    
    private func initSocketV6() -> SocketErrorType?
    {
        let (socket, error) = createSocket(serverPort, isV6: true)
        serverSocketV6 = socket
        return error
    }

    private func createSocket(port: UInt16, isV6: Bool) -> (CFSocket?, SocketErrorType?)
    {
        var socketContext = CFSocketContext(version: 0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
        var outSocket : CFSocket? = nil;
        var error : SocketErrorType? = nil
        withUnsafePointer(&socketContext) {
            if isV6 {
                outSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET6, 0, 0, 2, handleConnectionAccept, UnsafePointer<CFSocketContext>($0));
            } else {
                outSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, 0, 0, 2, handleConnectionAccept, UnsafePointer<CFSocketContext>($0));
            }
            
            var sincfd : CFData?
            if isV6 {
                var sin6 = sockaddr_in6();
                sin6.sin6_len = UInt8(sizeof(sockaddr_in6));
                sin6.sin6_family = sa_family_t(AF_INET6);
                sin6.sin6_port = UInt16(port).bigEndian
                sin6.sin6_addr = in6addr_any;
                let sin6_len = sizeof(sockaddr_in)
                
                withUnsafePointer(&sin6) {
                    sincfd = CFDataCreate(
                        kCFAllocatorDefault,
                        UnsafePointer($0),
                        sin6_len);
                }
            } else {
                var sin = sockaddr_in();
                sin.sin_len = UInt8(sizeof(sockaddr_in));
                sin.sin_family = sa_family_t(AF_INET);
                sin.sin_port = UInt16(port).bigEndian
                sin.sin_addr.s_addr = 0
                let sin_len = sizeof(sockaddr_in)
                withUnsafePointer(&sin) {
                    sincfd = CFDataCreate(
                        kCFAllocatorDefault,
                        UnsafePointer($0),
                        sin_len);
                }
            }
            let err = CFSocketSetAddress(outSocket, sincfd);
            if err != CFSocketError.Success {
                error = SocketErrorType(message: "Unable to set address on socket")
                let errstr : String? =  String.fromCString(strerror(errno));
                NSLog ("Socket Set Address Error: \(err.rawValue), \(errno), \(errstr)")
            }
        }
        if error == nil {
            let flags = CFSocketGetSocketFlags(outSocket)
            CFSocketSetSocketFlags(outSocket, flags | kCFSocketAutomaticallyReenableAcceptCallBack)
            let socketSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, outSocket, 0)
            CFRunLoopAddSource(transportRunLoop, socketSource, kCFRunLoopDefaultMode)
        }
        return (outSocket, error)
    }
    
    private func asUnsafeMutableVoid() -> UnsafeMutablePointer<Void>
    {
        let selfAsOpaque = Unmanaged<CFSocketServer>.passUnretained(self).toOpaque()
        let selfAsVoidPtr = UnsafeMutablePointer<Void>(selfAsOpaque)
        return selfAsVoidPtr
    }
}

