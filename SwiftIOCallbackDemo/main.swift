

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
    var pipe : Pipe
    private var buffer = UnsafeMutablePointer<UInt8>.alloc(BUFFER_LENGTH)

    init(pipe : Pipe)
    {
        self.pipe = pipe
    }
    
    func start()
    {
        readAndEcho()
    }
    
    func readAndEcho()
    {
        pipe.read(buffer, length: BUFFER_LENGTH) { (buffer, length, error) -> () in
            if error == nil {
                self.pipe.write(buffer, length: length, callback: nil);
                self.readAndEcho()
            }
        }
    }
}

var connections = [EchoConnection]()

class EchoFactory : StreamFactory {
    func createNewStream() -> Connection {
        return SimpleStream()
    }
    
    func connectionStarted(connection: Connection) {
        let pipe = connection as! Pipe
        let echoConn = EchoConnection(pipe: pipe)
        connections.append(echoConn)
        echoConn.start()
    }
}

var server = CFSocketServerTransport(nil)
server.streamFactory = EchoFactory()
server.start()

while CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
    print("Clocked ticked...")
}

