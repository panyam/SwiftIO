

#if os(Linux)
    import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation
import SwiftIO

print("Testing....")

let BUFFER_LENGTH = 8192

class EchoConnection
{
    var socketStream : SocketStream
    private var buffer = UnsafeMutablePointer<UInt8>.alloc(BUFFER_LENGTH)

    init(sockStream : SocketStream)
    {
        socketStream = sockStream
    }
    
    func start()
    {
        readAndEcho()
    }
    
    func readAndEcho()
    {
        socketStream.read(buffer, length: BUFFER_LENGTH) { (buffer, length, error) -> () in
            if error == nil {
                self.socketStream.write(buffer, length: length, callback: nil);
                self.readAndEcho()
            }
        }
    }
}

var connections = [EchoConnection]()

class EchoFactory : ConnectionFactory {
    func createNewConnection() -> Connection {
        return SocketStream()
    }
    
    func connectionStarted(connection: Connection) {
        let sockStream = connection as! SocketStream
        let echoConn = EchoConnection(sockStream: sockStream)
        connections.append(echoConn)
        echoConn.start()
    }
}

var server = CFSocketServerTransport(nil)
server.connectionFactory = EchoFactory()
server.start()

while CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
    print("Clocked ticked...")
}

