//
//  FileStreams.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/24/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class FileStream : Stream
{
    var consumer : CFStreamConsumer?
    var producer : CFStreamProducer?
    var filePath : String
    var accessMode : String
    
    public init(path: String, mode: String)
    {
        filePath = path
        accessMode = mode
        
        let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, CFURLPathStyle.CFURLPOSIXPathStyle, false)
        if mode == "r" {
            consumer = CFStreamConsumer(nil)
            consumer!.setReadStream(CFReadStreamCreateWithFile(kCFAllocatorDefault, fileURL))
        } else if mode == "w" {
            producer = CFStreamProducer(nil)
            producer!.setWriteStream(CFWriteStreamCreateWithFile(kCFAllocatorDefault, fileURL))
        }
    }

    public func setReadyToWrite()
    {
        producer?.setReadyToWrite()
    }

    public func setReadyToRead()
    {
        consumer?.setReadyToRead()
    }

    public func close()
    {
        consumer?.close()
        producer?.close()
    }

    public func ensureRunLoop(block: (() -> Void))
    {
    }

    public func dispatchToRunLoop(block: (() -> Void))
    {
    }
}

public class FileReader : Reader
{
    var consumer : CFStreamConsumer?
    var streamReader : StreamReader
    var filePath : String
    
    public init(path: String)
    {
        filePath = path
        let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, CFURLPathStyle.CFURLPOSIXPathStyle, false)
        consumer = CFStreamConsumer(nil)
        consumer!.setReadStream(CFReadStreamCreateWithFile(kCFAllocatorDefault, fileURL))
    }
    
    public func close()
    {
        consumer?.close()
    }
    
    func read(buffer: BufferType, length: Int, callback: IOCallback?)
    {
    }
}