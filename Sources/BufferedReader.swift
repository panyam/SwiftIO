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
    
    public var bytesAvailable : LengthType {
        get {
            return dataBuffer.length
        }
    }
    
    public func read() -> (value: UInt8, error: ErrorType?) {
        if dataBuffer.length == 0
        {
            return (0, IOErrorType.Unavailable)
        } else {
            return (dataBuffer.advanceBy(0), nil)
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
            readBuffer.assignFrom(dataBuffer.current, count: min(readLength, length))
            dataBuffer.advanceBy(min(readLength, length))
            
            callback?(length: min(readLength, length), error: nil)
        } else {
            dataBuffer.read(reader, callback: { (length, error) in
                callback?(length: min(readLength, self.dataBuffer.length), error: error)
            })
        }
    }
}