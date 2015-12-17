

import CoreFoundation

/**
 * The connection object that is the interface to the underlying transport.
 */
public protocol ClientTransport {
    func setReadyToWrite()
    func setReadyToRead()
    func close()
    func performBlock(block: (() -> Void))
}

public protocol Connection {
    /**
     * The underlying connection object this is listening to.
     */
    var transport : ClientTransport? { get set }
    
    /**
     * Called when the connection has been closed.
     */
    func connectionClosed()
    
    /**
     * Called when read error received.
     */
    func receivedReadError(error: SocketErrorType)
    
    /**
     * Called when write error received.
     */
    func receivedWriteError(error: SocketErrorType)
    
    /**
     * Called by the transport when it is ready to send data.
     * Returns the number of bytes of data available.
     */
    func writeDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: Int)?
    
    /**
     * Called into indicate numWritten bytes have been written.
     */
    func dataWritten(numWritten: Int)
    
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

public protocol ConnectionFactory {
    /**
     * Called when a new connection has been created and appropriate data needs
     * needs to be initialised for this.
     */
    func createNewConnection() -> Connection
    func connectionStarted(connection : Connection)
}

public protocol ServerTransport {
    var connectionFactory : ConnectionFactory? { get set }
    func start() -> SocketErrorType?
    func stop()
}
