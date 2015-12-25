//
//  Streams.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/17/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public typealias BufferType = UnsafeMutablePointer<UInt8>
public typealias IOCallback = (length: Int, error: ErrorType?) -> ()

public protocol RunLoop
{
    /**
     * Starts the runloop
     */
    func start()
    /**
     * Stops the runloop
     */
    func stop()
    /**
     * Ensures that the block is performed within the runloop (if not already happening)
     */
    func ensure(block: () -> Void)
    /**
     * Enqueues a block to be run on the runloop.
     */
    func enqueue(block: () -> Void)
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
    func read(buffer: BufferType, length: Int, callback: IOCallback?)
}

public protocol Writer {
    func write(buffer: BufferType, length: Int, callback: IOCallback?)
}

public extension Writer {
    public func writeString(string: String, callback: IOCallback?)
    {
        let nsString = string as NSString
        let length = nsString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        write(UnsafeMutablePointer<UInt8>(nsString.UTF8String), length: length, callback: callback)
    }
}

///**
// * The object that is the interface to the underlying transport from which
// * data is read/written to.
// */
//public protocol Stream {
//}

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

public protocol StreamConsumer {
    /**
     * Called when read error received.
     */
    func receivedReadError(error: SocketErrorType)
    
    /**
     * Called by the transport when it can pass data to be processed.
     * Returns a buffer (and length) into which at most length number bytes will be filled.
     */
    func readDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: Int)?
    
    /**
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     */
    func dataReceived(length: Int)
}

public protocol StreamProducer {
    /**
     * Called when write error received.
     */
    func receivedWriteError(error: SocketErrorType)
    
    /**
     * Called by the transport when it is ready to send data.
     * Returns the number of bytes of data available.
     */
    func writeDataRequested() -> (buffer: BufferType, length: Int)?
    
    /**
     * Called into indicate numWritten bytes have been written.
     */
    func dataWritten(numWritten: Int)
}

public protocol StreamFactory {
    /**
     * Called when a new stream has been created and appropriate data needs
     * needs to be initialised for this.
     */
    func streamStarted(stream : Stream)
}


public protocol StreamServer {
    var streamFactory : StreamFactory? { get set }
    func start() -> ErrorType?
    func stop()
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
    private var writeRequests = [IORequest]()
    
    public init(_ stream: Stream)
    {
        self.stream = stream
    }

    public func write(buffer: BufferType, length: Int, callback: IOCallback?)
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
     * Called by the transport when it is ready to send data.
     * Returns the number of bytes of data available.
     */
    public func writeDataRequested() -> (buffer: BufferType, length: Int)?
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
            if request.remaining() == 0
            {
                // done so pop it off
                writeRequests.removeFirst()
                request.invokeCallback(nil)
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
    /**
     * The underlying connection object this is listening to.
     */
    private var readRequests = [IORequest]()
    private(set) var stream : Stream
    
    public init(_ stream: Stream)
    {
        self.stream = stream
    }
    
    public func read(buffer: BufferType, length: Int, callback: IOCallback?)
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
            //            if request.remaining() == 0 {
            // done so pop it off
            readRequests.removeFirst()
            request.invokeCallback(nil)
            //            }
        }
    }
}

//
//public class SimpleStream : Stream {
//    public var transport : Transport?
//    public var consumer : StreamConsumer?
//    public var producer : StreamProducer?
//    
//    public init()
//    {
//        producer = StreamWriter(self)
//        consumer = StreamReader(self)
//    }
//}
//

private class IORequest
{
    var buffer: BufferType
    var length: Int
    var satisfied = 0
    var callback: IOCallback?
    init(buffer: BufferType, length: Int, callback: IOCallback?)
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

