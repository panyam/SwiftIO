//
//  Streams.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/17/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public typealias BufferType = UnsafeMutablePointer<UInt8>
public typealias IOCallback = (buffer: BufferType, length: Int, error: ErrorType?) -> ()

public protocol Closeable {
    func close()
}

/**
 * The Reader protocol is used when an asynchronous read is issued for upto 'length' number 
 * of bytes to be read into the client provided buffer.  Once atleast one byte is read (or
 * error is encountered), the callback is called.   It can be assumed that the Reader will
 * most likely modify the buffer that was provided to call so the client must ensure that
 * either reads are queued by issue reads successively within each callback or by using
 * a queuing reader (such as the Pipe or BufferedReader) or by providing a different
 * buffer in each call.
 */
public protocol Reader {
    func read(buffer: BufferType, length: Int, callback: IOCallback?)
}

public protocol Writer {
    func write(buffer: BufferType, length: Int, callback: IOCallback?)
}

public extension Writer {
    public func writeString(string: String, callback: IOCallback?)
    {
        let nsString = string as NSString
        let length = nsString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        write(UnsafeMutablePointer<UInt8>(nsString.UTF8String), length: length, callback: callback)
    }
}