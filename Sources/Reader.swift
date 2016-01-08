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
    
    public func readNBytes(numBytes : Int, bigEndian: Bool, callback : ((value : Int64, error: ErrorType?) -> Void)?)
    {
        var numBytesLeft = numBytes
        var output : Int64 = 0
        
        func consumeByte(nextByte : UInt8) -> Bool
        {
            if bigEndian {
                output = (output << 8) | (Int64(Int8(bitPattern: nextByte)) & 0xff)
            } else {
                output = ((Int64(Int8(bitPattern: nextByte)) & 0xff) << 8) | (output & 0xff)
            }
            numBytesLeft--
            if numBytesLeft == 0
            {
                callback?(value: output, error: nil)
                return false
            }
            return true
        }

        func readNextByte(error: ErrorType?)
        {
            if error != nil
            {
                callback?(value: output, error: error)
                return
            }
            while bytesReadable > 0 && numBytesLeft > 0
            {
                let (nextByte, error) = read()
                if error == nil
                {
                    consumeByte(nextByte)
                    readNextByte(nil)
                } else {
                    callback?(value: output, error: error)
                }
            }

            if bytesReadable == 0 && numBytesLeft > 0
            {
                peek{ (value, error) in
                    readNextByte(error)
                }
            } else {
            }
        }
        readNextByte(nil)
    }
    
    public func readInt8(callback : ((value : Int8, error : ErrorType?) -> Void)?)
    {
        return readNBytes(1, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: Int8(truncatingBitPattern: (value & 0x00000000000000ff)), error: error)
        })
    }
    
    public func readInt16(callback : ((value : Int16, error : ErrorType?) -> Void)?)
    {
        return readNBytes(2, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: Int16(truncatingBitPattern: (value & 0x000000000000ffff)), error: error)
        })
    }
    
    public func readInt32(callback : ((value : Int32, error : ErrorType?) -> Void)?)
    {
        return readNBytes(4, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: Int32(truncatingBitPattern: (value & 0x00000000ffffffff)), error: error)
        })
    }
    
    public func readInt64(callback : ((value : Int64, error : ErrorType?) -> Void)?)
    {
        return readNBytes(8, bigEndian: true, callback: callback)
    }
    
    public func readUInt8(callback : ((value : UInt8, error : ErrorType?) -> Void)?)
    {
        return readNBytes(1, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: UInt8(truncatingBitPattern: (value & 0x00000000000000ff)), error: error)
        })
    }
    
    public func readUInt16(callback : ((value : UInt16, error : ErrorType?) -> Void)?)
    {
        return readNBytes(2, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: UInt16(truncatingBitPattern: (value & 0x000000000000ffff)), error: error)
        })
    }
    
    public func readUInt32(callback : ((value : UInt32, error : ErrorType?) -> Void)?)
    {
        return readNBytes(4, bigEndian: true, callback: {(value: Int64, error: ErrorType?) in
            callback?(value: UInt32(truncatingBitPattern: (value & 0x00000000ffffffff)), error: error)
        })
    }
    
    public func readUInt64(callback : ((value : UInt64, error : ErrorType?) -> Void)?)
    {
        let origCallback = callback
        return readNBytes(8, bigEndian: true, callback: { (value, error) in
            origCallback?(value: UInt64(value), error: error)
        })
    }
}
