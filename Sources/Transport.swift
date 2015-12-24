

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

public protocol ServerTransport {
    var streamFactory : StreamFactory? { get set }
    func start() -> ErrorType?
    func stop()
}
