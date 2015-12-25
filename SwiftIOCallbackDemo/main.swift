

#if os(Linux)
    import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation
import SwiftIO

print("Testing....")

class EchoStream
{
    var stream : Stream
    private var buffer = UnsafeMutablePointer<UInt8>.alloc(DEFAULT_BUFFER_LENGTH)

    init(stream : Stream)
    {
        self.stream = stream
    }
    
    func start()
    {
        readAndEcho()
    }
    
    func readAndEcho()
    {
        let reader = stream.consumer as! StreamReader
        let writer = stream.producer as! StreamWriter
        reader.read(buffer, length: DEFAULT_BUFFER_LENGTH) { (length, error) -> () in
            if error == nil {
                writer.write(self.buffer, length: length, callback: nil);
                self.readAndEcho()
            }
        }
    }
}

var streams = [EchoStream]()

class EchoFactory : StreamFactory {
    func streamStarted(stream: Stream) {
        let echoConn = EchoStream(stream: stream)
        streams.append(echoConn)
        echoConn.start()
    }
}

var server = CFSocketServer(nil)
server.streamFactory = EchoFactory()
server.start()

while CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
    print("Clocked ticked...")
}

