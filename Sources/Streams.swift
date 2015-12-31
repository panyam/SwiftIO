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

public protocol StreamConsumer {
    /**
     * Called when read error received.
     */
    func receivedReadError(error: SocketErrorType)
    
    /**
     * Called by the stream when it can pass data to be processed.
     * Returns a buffer (and length) into which at most length number bytes will be filled.
     */
    func readDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: Int)?
    
    /**
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     * @param   length  Number of bytes read.  0 if EOF reached.
     */
    func dataReceived(length: Int)
    
    /**
     * Called when the parent stream is closed.
     */
    func streamClosed()
}

public protocol StreamProducer {
    /**
     * Called when write error received.
     */
    func receivedWriteError(error: SocketErrorType)
    
    /**
     * Called by the stream when it is ready to send data.
     * Returns the number of bytes of data available.
     */
    func writeDataRequested() -> (buffer: WriteBufferType, length: Int)?
    
    /**
     * Called into indicate numWritten bytes have been written.
     */
    func dataWritten(numWritten: Int)
    
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

