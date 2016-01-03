//
//  Reader.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 1/3/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import Foundation


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
     * the reading getting blocked.
     */
    var bytesAvailable : LengthType { get }
    
    /**
     * Returns the next byte that can be returned without blocking.
     * If no bytes are available then (0, Unavailable) is returned.
     */
    func read() -> (value: UInt8, error: ErrorType?)
    
    /**
     * Reads upto length number of bytes into the given buffer upon which
     * the callback is invoked with the number of bytes read (or error).
     */
    func read(buffer: ReadBufferType, length: LengthType, callback: IOCallback?)
    
    /**
    * Looks ahead enough data so that it can be read with the non-blocking
    * synchronous read call above.
    */
    //    func peek(callback: IOCallback)
}
