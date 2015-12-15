

#if os(Linux)
import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation
import SwiftSocketServer

print("Testing....")

class EchoConnection : Connection
{
    var transport : ClientTransport?
    private var buffer = UnsafeMutablePointer<UInt8>.alloc(8192)
    private var length = 0
    
    /**
     * Called when the connection has been closed.
     */
    func connectionClosed()
    {
        print("Good bye!")
    }
    
    /**
     * Called by the transport when it is ready to send data.
     * Returns the number of bytes of data available.
     */
    func writeDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: Int)?
    {
        return nil
    }
    
    /**
     * Called into indicate numWritten bytes have been written.
     */
    func dataWritten(numWritten: Int)
    {
    }
    
    /**
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     */
    func dataReceived(buffer: UnsafePointer<UInt8>, length: Int)
    {
    }
}

class EchoFactory : ConnectionFactory {
    func connectionAccepted() -> Connection {
        return EchoConnection()
    }
}

var server = CFSocketServerTransport()
server.connectionFactory = EchoFactory()
server.start()

while CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
    print("Clocked ticked...")
}

