//
//  Streams.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/17/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public protocol Stream {
    /**
     * The underlying connection object this is listening to.
     */
    func setReadyToWrite()
    func setReadyToRead()
    func close()
    var runLoop : RunLoop { get }
    var consumer : StreamConsumer? { get set }
    var producer : StreamProducer? { get set }
}

public protocol DataReceiver {
    func read(buffer: ReadBufferType, length: LengthType) -> (LengthType, ErrorType?)
}

public protocol StreamConsumer {
    /**
     * Called when read error received.
     */
    func receivedReadError(error: ErrorType)

    /**
     * Called when the stream has data to be received.
     * receiver.read Can called by the consumer until data is left.
     */
//    func canReceiveData(receiver: DataReceiver) -> Bool

    /**
     * Called by the stream when it can pass data to be processed.
     * Returns a buffer (and length) into which at most length number bytes will be filled.
     */
    func readDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: LengthType)?
    
    /**
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     * @param   length  Number of bytes read.  0 if EOF reached.
     */
    func dataReceived(length: LengthType)
    
    /**
     * Called when the parent stream is closed.
     */
    func streamClosed()
}

public protocol DataSender {
    /**
     * Called to write data to the underlying channel.
     * If no more data can be written (0, nil) is returned.
     *
     */
    func write(buffer: WriteBufferType, length: LengthType) -> (LengthType, ErrorType?)
}

public protocol StreamProducer {
    /**
     * Called when write error received.
     */
    func receivedWriteError(error: ErrorType)

    /**
     * Called when the stream is available to send data.
     * Can called by the producer until no more data is left or can be sent.
     */
     func canSendData(sender: DataSender) -> Bool
//
//    /**
//     * Called by the stream when it is ready to send data.
//     * Returns the number of bytes of data available.
//     */
//    func writeDataRequested() -> (buffer: WriteBufferType, length: LengthType)?
//    
//    /**
//     * Called into indicate numWritten bytes have been written.
//     */
//    func dataWritten(numWritten: LengthType)
    
    /**
     * Called when the parent stream is closed.
     */
    func streamClosed()
}

public protocol StreamHandler {
    /**
     * Called when a new stream has been created and appropriate data needs
     * needs to be initialised for this.
     */
    func handleStream(stream : Stream)
}


public protocol StreamServer {
    var streamHandler : StreamHandler? { get set }
    func start() -> ErrorType?
    func stop()
}


/**
 * Implements an async IO writer for a StreamProducer.
 * With the traditional callback based writes, the caller has to keep track of how much
 * was written and incrementing the buffer pointers accordingly.  This makes it easy
 * to simply queue a write of a given buffer and forget it.  Ofcourse this requires that
 * the caller be willing to transfer ownership of the buffer to writer.
 */
public class StreamWriter : Writer, StreamProducer
{
    private var requestCount : UInt = 0
    private var writeRequests = [IORequest]()
    /**
     * The underlying connection object this is listening to.
     */
    private(set) var theStream : Stream
    
    public var stream : Stream {
        return theStream
    }
    
    public init(_ stream: Stream)
    {
        theStream = stream
    }
    
    public func flush()
    {
//        if completion != nil {
//            stream.runLoop.ensure {
//                self.writeRequests.append(IORequest(buffer: nil, length: 0, callback: completion))
//            }
//        }
    }
    
    public func write(value: UInt8, _ callback: CompletionCallback?)
    {
        // TODO: has to be better way than creating a buffer each time!
        let buffer = WriteBufferType.alloc(1)
        buffer[0] = value
        self.write(buffer, length: 1) {(length: LengthType, error: ErrorType?) in
            callback?(error: error)
        }
    }
    
    public func write(buffer: WriteBufferType, length: LengthType, _ callback: IOCallback?)
    {
        requestCount += 1
        stream.runLoop.ensure {
            let request = IORequest(buffer: buffer, length: length, callback: callback)
            request.requestId = self.requestCount
            self.writeRequests.append(request)
            self.stream.setReadyToWrite()
        }
    }
    
    public func streamClosed() {
        receivedWriteError(IOErrorType.Closed)
    }
    
    public func receivedWriteError(error: ErrorType) {
        while !writeRequests.isEmpty
        {
            let nextRequest = writeRequests.removeFirst()
            stream.runLoop.enqueue {
                nextRequest.invokeCallback(error)
            }
        }
    }
    
    public func canSendData(sender: DataSender) -> Bool {
        while !writeRequests.isEmpty
        {
            let request = writeRequests.first!
            let (bytesWritten, error) = sender.write(request.current, length: request.remaining)
            if error != nil
            {
                receivedWriteError(error!)
                return false
            } else if bytesWritten == 0
            {
                // no more writes possible for now
                return !writeRequests.isEmpty
            } else {
                dataWritten(bytesWritten)
            }
        }
        return false
    }

    /**
     * Called by the stream when it is ready to send data.
     * Returns the number of bytes of data available.
     */
    public func writeDataRequested() -> (buffer: WriteBufferType, length: LengthType)?
    {
        // remove all flush requests
        if let request = writeRequests.first {
            return (request.buffer.advancedBy(request.satisfied), request.remaining)
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
            if request.remaining == 0
            {
                // done so pop it off
                writeRequests.removeFirst()
                request.invokeCallback(nil)
                
                // remove all flush requests that may appear here
                while !writeRequests.isEmpty && writeRequests.first?.length == 0
                {
                    writeRequests.removeFirst().callback?(length: 0, error: nil)
                }
            }
        }
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
    private var requestCount : UInt = 0
    /**
     * The underlying connection object this is listening to.
     */
    public var readRequests = [IORequest]()
    /**
     * The underlying connection object this is listening to.
     */
    private(set) var theStream : Stream
    
    public var stream : Stream {
        return theStream
    }
    
    public init(_ stream: Stream)
    {
        theStream = stream
    }
    
    public var bytesReadable : LengthType {
        return 0
    }
    
    public func peek(callback: PeekCallback?) {
        assert(false, "Not yet implemented")
    }
    
    public func read() -> (value: UInt8, error: ErrorType?) {
        return (0, IOErrorType.Unavailable)
    }
    
    public func read(buffer: ReadBufferType, length: LengthType, callback: IOCallback?)
    {
        assert(self.readRequests.isEmpty)
        requestCount += 1
        stream.runLoop.ensure {
            let request = IORequest(buffer: buffer, length: length, callback: callback)
            request.requestId = self.requestCount
            self.readRequests.append(request)
            self.stream.setReadyToRead()
        }
    }
    
    public func canReceiveData(receiver: DataReceiver) -> Bool {
        while !readRequests.isEmpty
        {
            let request = readRequests.first!
            let (bytesRead, error) = receiver.read(request.buffer.advancedBy(request.satisfied), length: request.remaining)
            if error != nil
            {
                receivedReadError(error!)
                return false
            } else if bytesRead == 0
            {
                // no more writes possible for now
                return !readRequests.isEmpty
            } else {
                dataReceived(bytesRead)
            }
        }
        return false
    }
    
    public func readDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: LengthType)? {
        if let request = readRequests.first {
            return (request.buffer.advancedBy(request.satisfied), request.remaining)
        }
        return nil
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
            // done so pop it off
            readRequests.removeFirst()
            request.invokeCallback(nil)
        }
    }
    
    public func streamClosed() {
        receivedReadError(IOErrorType.Closed)
    }
    
    public func receivedReadError(error: ErrorType) {
        while !readRequests.isEmpty
        {
            let nextRequest = readRequests.removeFirst()
            stream.runLoop.enqueue {
                nextRequest.invokeCallback(error)
            }
        }
    }
}

public class IORequest
{
    var requestId : UInt = 0
    var boolSingleByte = false
    var buffer: ReadBufferType
    var length: LengthType
    var satisfied : LengthType = 0
    var callback: IOCallback?
    init(buffer: ReadBufferType, length: LengthType, callback: IOCallback?)
    {
        self.buffer = buffer
        self.length = length
        self.callback = callback
    }
    
    var remaining : LengthType { return length - satisfied }
    var current : ReadBufferType {
        get {
            return buffer.advancedBy(satisfied)
        }
    }
    
    func invokeCallback(err: ErrorType?)
    {
        if callback != nil {
            callback!(length: satisfied, error: err)
        }
    }
}
