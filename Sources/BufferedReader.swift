//
//  BufferedStream.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/18/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class BufferedReader : Reader {
    private var reader : Reader
    private var dataBuffer : Buffer
    private var bufferSize : LengthType = 0
    
    public init (_ reader: Reader, bufferSize: LengthType)
    {
        self.reader = reader
        self.bufferSize = bufferSize
        self.dataBuffer = Buffer(bufferSize)
    }
    
    public convenience init (_ reader: Reader)
    {
        self.init(reader, bufferSize: DEFAULT_BUFFER_LENGTH)
    }
    
    public var stream : Stream {
        return reader.stream
    }

    public var bytesReadable : LengthType {
        return dataBuffer.length
    }
    
    public func read() -> (value: UInt8, error: ErrorType?) {
        if dataBuffer.length == 0
        {
            return (0, IOErrorType.Unavailable)
        } else {
            return (dataBuffer.advanceBy(1), nil)
        }
    }

    /**
     * Initiate a read for at least one byte.
     */
    public func read(buffer: ReadBufferType, length: LengthType, callback: IOCallback?)
    {
        let readBuffer = buffer
        let readLength = length

        if dataBuffer.length > 0
        {
            // then copy it
            if buffer != nil
            {
                readBuffer.assignFrom(dataBuffer.current, count: min(readLength, length))
                dataBuffer.advanceBy(min(readLength, length))
                callback?(length: min(readLength, length), error: nil)
            } else {
                // a nil buffer was passed so just return 0 to tell the caller we have data
                callback?(length: 0, error: nil)
            }
        } else {
            dataBuffer.read(reader) { (length, error) in
                callback?(length: min(readLength, self.dataBuffer.length), error: error)
            }
        }
    }
}