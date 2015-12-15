
/**
 * The connection object that is the interface to the underlying transport.
 */
protocol ClientTransport {
    func setWriteable()
}

protocol Connection {
    /**
     * The underlying connection object this is listening to.
     */
    var transport : ClientTransport? { get set }
    
    /**
     * Called when the connection has been closed.
     */
    func connectionClosed()
    
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
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     */
    func dataReceived(buffer: UnsafePointer<UInt8>, length: Int)
}

protocol ConnectionFactory {
    /**
     * Called when a new connection has been created and appropriate data needs
     * needs to be initialised for this.
     */
    func connectionAccepted() -> Connection
}

protocol ServerTransport {
    var connectionFactory : ConnectionFactory? { get set }
    func start()
    func stop()
}
