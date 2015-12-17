//
//  SocketStream.swift
//  SwiftSocketServer
//
//  Created by Sriram Panyam on 12/16/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public typealias BufferType = UnsafeMutablePointer<UInt8>
public typealias IOCallback = (buffer: BufferType?, length: Int?, error: ErrorType?) -> ()

public class ConnectionClosedError : ErrorType {
}

/**
 * Implements an async IO wrapper over the Connection.
 * With a traditional connection, all reads and writes happen via
 * event callbacks.  A disadvantage of this is that more and more
 * complex state machines would have to be built and maintained.
 *
 * To over come this, this class provides read and write methods
 * with async callbacks.
 */
public class SocketStream : Connection {
    private class IORequest
    {
        var buffer: BufferType
        var length: Int
        var satisfied = 0
        var callback: IOCallback
        init(buffer: BufferType, length: Int, callback: IOCallback)
        {
            self.buffer = buffer
            self.length = length
            self.callback = callback
        }
        
        func remaining() -> Int
        {
            return length - satisfied
        }
        
        func invokeCallback(err: ErrorType?) {
            callback(buffer: buffer, length: length, error: err)
        }
    }
    
    /**
     * The underlying connection object this is listening to.
     */
    public var transport : ClientTransport?
    private var readRequests = [IORequest]()
    private var writeRequests = [IORequest]()

    public func read(buffer: BufferType, length: Int, callback: IOCallback)
    {
        transport?.performBlock({ () -> Void in
            self.readRequests.append(IORequest(buffer: buffer, length: length, callback: callback))
            self.transport?.setReadyToRead()
        })
    }
    
    public func write(buffer: BufferType, length: Int, callback: IOCallback)
    {
        transport?.performBlock({ () -> Void in
            self.writeRequests.append(IORequest(buffer: buffer, length: length, callback: callback))
            self.transport?.setReadyToWrite()
        })
    }

    /**
     * Called when the connection has been closed.
     */
    public func connectionClosed()
    {
    }
    
    public func receivedReadError(error: SocketErrorType) {
        for request in readRequests {
            request.invokeCallback(error)
        }
        readRequests.removeAll()
    }
    
    public func receivedWriteError(error: SocketErrorType) {
        for request in writeRequests {
            request.invokeCallback(error)
        }
        writeRequests.removeAll()
    }
    
    /**
     * Called by the transport when it is ready to send data.
     * Returns the number of bytes of data available.
     */
    public func writeDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: Int)?
    {
        if let request = writeRequests.first {
            return (request.buffer.advancedBy(request.satisfied), request.remaining())
        }
        return nil
    }
    
    /**
     * Called into indicate numWritten bytes have been written.
     */
    public func dataWritten(numWritten: Int)
    {
        assert(!writeRequests.isEmpty, "Write request queue cannot be empty when we have a data callback")
        if let request = writeRequests.first {
            request.satisfied += numWritten
            if request.remaining() == 0 {
                // done so pop it off
                writeRequests.removeFirst()
                request.invokeCallback(nil)
            }
        }
    }
    
    public func readDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: Int)? {
        if let request = readRequests.first {
            return (request.buffer.advancedBy(request.satisfied), request.remaining())
        }
        return nil
    }
    
    /**
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     */
    public func dataReceived(length: Int)
    {
        assert(!readRequests.isEmpty, "Write request queue cannot be empty when we have a data callback")
        if let request = readRequests.first {
            request.satisfied += length
            if request.remaining() == 0 {
                // done so pop it off
                readRequests.removeFirst()
                request.invokeCallback(nil)
            }
        }
    }
}