//
//  FileStreams.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/24/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

/**
 * Returns the size of a given file.
 */
public func SizeOfFile(filePath: String) -> LengthType? {
    // TODO: check linux
    do {
        let attr : NSDictionary? = try NSFileManager.defaultManager().attributesOfItemAtPath(filePath)
        
        if let _attr = attr {
            return LengthType(_attr.fileSize());
        }
    } catch {
        print("Error: \(error)")
    }
    return nil
}

public func FileReader(filePath : String) -> StreamReader
{
    let fileStream = CFStream(nil)
    let reader = StreamReader(fileStream)
    
    // TODO: this is OSX/CF specific - need a way to make this platform independant
    let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, CFURLPathStyle.CFURLPOSIXPathStyle, false)
    let readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, fileURL)
    fileStream.setReadStream(readStream)
    fileStream.consumer = reader
    CFReadStreamOpen(readStream)
    return reader
}


public func FileWriter(filePath : String) -> StreamWriter
{
    let fileStream = CFStream(nil)
    let writer = StreamWriter(fileStream)
    
    // TODO: this is OSX/CF specific - need a way to make this platform independant
    let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, CFURLPathStyle.CFURLPOSIXPathStyle, false)
    let writeStream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, fileURL)
    fileStream.setWriteStream(writeStream)
    fileStream.producer = writer
    CFWriteStreamOpen(writeStream)
    return writer
}
