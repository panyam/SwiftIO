//
//  Reader.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 1/3/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import Foundation

public typealias PeekCallback = (value: UInt8, error: ErrorType?) -> Void

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
    /**
     * The stream associated this reader is consuming from.
     */
    var stream : Stream { get }
    
    /**
     * Returns the number of bytes available that can be read without the
     * the read getting blocked.
     */
    var bytesReadable : LengthType { get }
    
    /**
     * Returns the next byte that can be returned without blocking.
     * If no bytes are available then (0, Unavailable) is returned.
     */
    func read() -> (value: UInt8, error: ErrorType?)

    /**
     * Peeks at the next byte without actually reading it
     */
    func peek(callback: PeekCallback?)

    /**
     * Reads upto length number of bytes into the given buffer upon which
     * the callback is invoked with the number of bytes read (or error).
     */
    func read(buffer: ReadBufferType, length: LengthType, callback: IOCallback?)
}


public extension Reader
{
    /**
     * Read till a particular character is encountered (not including the delimiter).
     */
    public func readTillChar(delimiter: UInt8, callback : ((str : String, error: ErrorType?) -> Void)?)
    {
        var returnedString = ""
        let originalCallback = callback
        while bytesReadable > 0
        {
            let (nextByte, error) = read()
            if error != nil
            {
                callback?(str: returnedString, error: error)
            } else if nextByte == delimiter
            {
                callback?(str: returnedString, error: nil)
                return
            } else {
                returnedString.append(Character(UnicodeScalar(nextByte)))
            }
        }

        peek { (value, error) -> Void in
            self.readTillChar(delimiter) { (str, error) -> Void in
                originalCallback?(str: returnedString + str, error: error)
            }
        }
    }
}
