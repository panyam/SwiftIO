//
//  IO.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/30/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public typealias LengthType = UInt
public typealias OffsetType = Int
public typealias ReadBufferType = UnsafeMutablePointer<UInt8>
public typealias WriteBufferType = UnsafeMutablePointer<UInt8>
public typealias IOCallback = (length: LengthType, error: ErrorType?) -> Void

public enum IOErrorType : ErrorType
{
    /**
     * When the pipe has closed and no more read/write is possible
     */
    case Closed

    /**
     * When the end of a stream has been reached and no more data can be read or written.
     */
    case EndReached
    
    /**
     * When no more data is currently available on a read stream (a read would result in a block until data is available)
     */
    case Unavailable
    
    public func equals(error: ErrorType?) -> Bool
    {
        if error == nil
        {
            return false
        }
        
        if let ioError = error as? IOErrorType
        {
            return ioError == self
        }
        return false
    }
}

/**
 * The Reader protocol is used when an asynchronous read is issued for upto 'length' number
 * of bytes to be read into the client provided buffer.  Once atleast one byte is read (or
 * error is encountered), the callback is called.   It can be assumed that the Reader will
 * most likely modify the buffer that was provided to call so the client must ensure that
 * either reads are queued by issue reads successively within each callback or by using
 * a queuing reader (such as the Pipe or BufferedReader) or by providing a different
 * buffer in each call.
 */
public protocol Reader {
    /**
     * Returns the number of bytes available that can be read without the
     * the reading getting blocked.
     */
    var bytesAvailable : LengthType { get }
    
    /**
     * Returns the next byte that can be returned without blocking.  
     * If no bytes are available then (0, Unavailable) is returned.
     */
    func read() -> (value: UInt8, error: ErrorType?)
    
    /**
     * Reads upto length number of bytes into the given buffer upon which
     * the callback is invoked with the number of bytes read (or error).
     */
    func read(buffer: ReadBufferType, length: LengthType, callback: IOCallback?)

    /**
     * Looks ahead enough data so that it can be read with the non-blocking 
     * synchronous read call above.
     */
//    func peek(callback: IOCallback)
}

public protocol Writer {
    func write(buffer: WriteBufferType, length: LengthType, _ callback: IOCallback?)
}

public extension Writer {
    public func writeString(string: String)
    {
        writeString(string, nil)
    }
    
    public func writeString(string: String, _ callback: IOCallback?)
    {
        let nsString = string as NSString
        let length = nsString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        write(WriteBufferType(nsString.UTF8String), length: LengthType(length), callback)
    }
}

/**
 * Implements an async IO writer for a StreamProducer.
 * With the traditional callback based writes, the caller has to keep track of how much
 * was written and incrementing the buffer pointers accordingly.  This makes it easy
 * to simply queue a write of a given buffer and forget it.  Ofcourse this requires that
 * a new buffer is provided for each write.
 */
public class StreamWriter : Writer, StreamProducer
{
    /**
     * The underlying connection object this is listening to.
     */
    private(set) var stream : Stream
    private var writeRequests = [IORequest<WriteBufferType>]()
    
    public init(_ stream: Stream)
    {
        self.stream = stream
    }
    
    public func flush(callback: IOCallback?)
    {
        stream.runLoop.ensure({ () -> Void in
            if self.writeRequests.isEmpty
            {
                callback?(length: 0, error: nil)
            } else {
                self.writeRequests.append(IORequest(buffer: nil, length: 0, callback: callback))
            }
        })
    }
    
    public func write(buffer: WriteBufferType, length: LengthType, _ callback: IOCallback?)
    {
        stream.runLoop.ensure({ () -> Void in
            self.writeRequests.append(IORequest(buffer: buffer, length: length, callback: callback))
            self.stream.setReadyToWrite()
        })
    }
    
    public func receivedWriteError(error: SocketErrorType) {
        for request in writeRequests {
            request.invokeCallback(error)
        }
        writeRequests.removeAll()
    }
    
    /**
     * Called by the stream when it is ready to send data.
     * Returns the number of bytes of data available.
     */
    public func writeDataRequested() -> (buffer: WriteBufferType, length: LengthType)?
    {
        if let request = writeRequests.first {
            return (request.buffer.advancedBy(request.satisfied), request.remaining())
        }
        return nil
    }
    
    /**
     * Called into indicate numWritten bytes have been written.
     */
    public func dataWritten(numWritten: LengthType)
    {
        assert(!writeRequests.isEmpty, "Write request queue cannot be empty when we have a data callback")
        if let request = writeRequests.first {
            request.satisfied += numWritten
            if request.remaining() == 0
            {
                // done so pop it off
                writeRequests.removeFirst()
                request.invokeCallback(nil)
                
                // remove all flush requests that may appear here
                while !writeRequests.isEmpty && writeRequests.first?.length == 0
                {
                    let ioRequest = writeRequests.first!
                    writeRequests.removeFirst()
                    ioRequest.callback?(length: 0, error: nil)
                }
            }
        }
    }
    
    public func streamClosed() {
        for request in writeRequests {
            request.invokeCallback(IOErrorType.Closed)
        }
        writeRequests.removeAll()
    }
}

/**
 * Implements an async IO reader for a StreamConsumer.
 * With a traditional connection, all reads happen via callbacks.  A disadvantage of
 * this is that more and more complex state machines would have to be built and maintained.
 *
 * To over come this, this class provides read methods with async callbacks.
 */
public class StreamReader : Reader, StreamConsumer {
    /**
     * The underlying connection object this is listening to.
     */
    private var readRequests = [IORequest<ReadBufferType>]()
    private(set) var stream : Stream
    
    public init(_ stream: Stream)
    {
        self.stream = stream
    }
    
    public var bytesAvailable : LengthType {
        get {
            return 0
        }
    }

    public func read() -> (value: UInt8, error: ErrorType?) {
        return (0, IOErrorType.Unavailable)
    }
    
    public func read(buffer: ReadBufferType, length: LengthType, callback: IOCallback?)
    {
        stream.runLoop.ensure({ () -> Void in
            self.readRequests.append(IORequest(buffer: buffer, length: length, callback: callback))
            self.stream.setReadyToRead()
        })
    }
    
    public func receivedReadError(error: SocketErrorType) {
        for request in readRequests {
            request.invokeCallback(error)
        }
        readRequests.removeAll()
    }
    
    public func readDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: LengthType)? {
        if let request = readRequests.first {
            return (request.buffer.advancedBy(request.satisfied), request.remaining())
        }
        return nil
    }
    
    public func streamClosed() {
        for request in readRequests {
            request.invokeCallback(IOErrorType.Closed)
        }
        readRequests.removeAll()
    }
    
    /**
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     */
    public func dataReceived(length: LengthType)
    {
        assert(!readRequests.isEmpty, "Read request queue cannot be empty when we have a data callback")
        if let request = readRequests.first {
            request.satisfied += length
            //            if request.remaining() == 0 {
            // done so pop it off
            readRequests.removeFirst()
            request.invokeCallback(nil)
            //            }
        }
    }
}

private class IORequest<BufferType>
{
    var buffer: BufferType
    var length: LengthType
    var satisfied = 0
    var callback: IOCallback?
    init(buffer: BufferType, length: LengthType, callback: IOCallback?)
    {
        self.buffer = buffer
        self.length = length
        self.callback = callback
    }
    
    func remaining() -> Int
    {
        return length - satisfied
    }
    
    func invokeCallback(err: ErrorType?)
    {
        if callback != nil {
            callback!(length: satisfied, error: err)
        }
    }
}

