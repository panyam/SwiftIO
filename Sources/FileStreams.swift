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
public func SizeOfFile(filePath: String) -> UInt64? {
    // TODO: check linux
    do {
        let attr : NSDictionary? = try NSFileManager.defaultManager().attributesOfItemAtPath(filePath)
        
        if let _attr = attr {
            return _attr.fileSize();
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
    fileStream.setReadStream(CFReadStreamCreateWithFile(kCFAllocatorDefault, fileURL))
    fileStream.consumer = reader
    return reader
}

public func FileWriter(filePath : String) -> StreamWriter
{
    let fileStream = CFStream(nil)
    let writer = StreamWriter(fileStream)
    
    // TODO: this is OSX/CF specific - need a way to make this platform independant
    let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, CFURLPathStyle.CFURLPOSIXPathStyle, false)
    fileStream.setWriteStream(CFWriteStreamCreateWithFile(kCFAllocatorDefault, fileURL))
    fileStream.producer = writer
    return writer
}
