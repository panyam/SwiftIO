

#if os(Linux)
import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation
import SwiftIO

print("Testing....")

let BUFFER_LENGTH = 8192

class EchoConnection : Connection
{
    var transport : ClientTransport?
    private var buffer = UnsafeMutablePointer<UInt8>.alloc(BUFFER_LENGTH)
    private var length = 0
    
    /**
     * Called when the connection has been closed.
     */
    func connectionClosed()
    {
        print("Good bye!")
        }
    
    func receivedReadError(error: SocketErrorType) {
        print("Read Error: \(error)")
    }
    
    func receivedWriteError(error: SocketErrorType) {
        print("Write Error: \(error)")
    }
    
    /**
     * Called by the transport when it is ready to send data.
     * Returns the number of bytes of data available.
     */
    func writeDataRequested() -> (buffer: BufferType, length: Int)?
    {
        print("Write data requested...");
        return (buffer, length)
    }
    
    /**
     * Called into indicate numWritten bytes have been written.
     */
    func dataWritten(numWritten: Int)
    {
        length -= numWritten
    }
    
    /**
     * Called by the transport when it can pass data to be processed.
     * Returns a buffer (and length) into which at most length number bytes will be filled.
     */
    func readDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: Int)?
    {
        return (buffer, BUFFER_LENGTH)
    }
    
    /**
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     */
    func dataReceived(length: Int)
    {
        self.length = length
        self.transport?.setReadyToWrite()
    }
}

class EchoFactory : ConnectionFactory {
    func createNewConnection() -> Connection {
        return EchoConnection()
    }
    func connectionStarted(connection : Connection)
    {
    }
}

var server = CFSocketServerTransport(nil)
server.connectionFactory = EchoFactory()
server.start()

while CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
    print("Clocked ticked...")
}

