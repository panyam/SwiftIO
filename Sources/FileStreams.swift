//
//  FileStreams.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/24/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class FileWriter // : Writer
{
    var writeStream : CFWriteStream?
    
    public init()
    {
    }
    
    public func open(filePath: String)
    {
        let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, CFURLPathStyle.CFURLPOSIXPathStyle, false)
        writeStream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, fileURL)
        CFWriteStreamOpen(writeStream)
        if (!CFWriteStreamOpen(writeStream)) {
            assert(false, "Handle this")
//            CFStreamError myErr = CFWriteStreamGetError(myWriteStream)
            // An error has occurred.
//            if (myErr.domain == kCFStreamErrorDomainPOSIX) {
//                // Interpret myErr.error as a UNIX errno.
//            } else if (myErr.domain == kCFStreamErrorDomainMacOSStatus) {
//                // Interpret myErr.error as a MacOS error code.
//                OSStatus macError = (OSStatus)myErr.error;
//                // Check other error domains.
//            }
        }
        
        var streamClientContext = CFStreamClientContext(version:0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
        let writeEvents = CFStreamEventType.CanAcceptBytes.rawValue | CFStreamEventType.ErrorOccurred.rawValue | CFStreamEventType.EndEncountered.rawValue
        withUnsafePointer(&streamClientContext) {
            if (CFWriteStreamSetClient(writeStream, writeEvents, fileWriteCallback, UnsafeMutablePointer<CFStreamClientContext>($0)))
            {
                CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
            }
        }
    }
    
    private func asUnsafeMutableVoid() -> UnsafeMutablePointer<Void>
    {
        let selfAsOpaque = Unmanaged<FileWriter>.passUnretained(self).toOpaque()
        let selfAsVoidPtr = UnsafeMutablePointer<Void>(selfAsOpaque)
        return selfAsVoidPtr
    }
}

/**
 * Callback for the write stream when data is available or errored.
 */
func fileWriteCallback(writeStream: CFWriteStream!, eventType: CFStreamEventType, info: UnsafeMutablePointer<Void>) -> Void
{
//    let fileWriter = Unmanaged<FileWriter>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
    if eventType == CFStreamEventType.CanAcceptBytes {
        print("Can accept bytes")
    } else if eventType == CFStreamEventType.EndEncountered {
        print("End Encountered")
    } else if eventType == CFStreamEventType.ErrorOccurred {
        print("Error Occured")
    }
}
