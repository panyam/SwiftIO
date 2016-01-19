//
//  BufferedStream.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/18/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class BufferedReader : Reader {
    public var reader : Reader
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
//            Log.debug("BR, Offset: \(dataBuffer.startOffset), EndOffset: \(dataBuffer.endOffset)")
            return (dataBuffer.advanceBy(1), nil)
        }
    }
    
    /**
     * Peeks at the next byte without actually reading it
     */
    public func peek(callback: PeekCallback?)
    {
        if dataBuffer.length == 0
        {
            dataBuffer.read(reader) { (length, error) in
                callback?(value: self.dataBuffer.advanceBy(0), error: error)
            }
        } else
        {
            callback?(value: dataBuffer.advanceBy(0), error: nil)
        }
    }

    /**
     * Initiate a read for at least one byte.
     */
    public func read(buffer: ReadBufferType, length: LengthType, callback: IOCallback?)
    {
        let readLength = length
        
        if dataBuffer.length > 0
        {
            // then copy it
            let readSize = min(length, dataBuffer.length)
//            Log.debug("BR, Offset: \(dataBuffer.startOffset), Length: \(readSize)")
            buffer.assignFrom(dataBuffer.current, count: readSize)
            dataBuffer.advanceBy(readSize)
            callback?(length: readSize, error: nil)
        } else {
//            Log.debug("ReadLength before read: \(readLength)")
            dataBuffer.read(reader) { (bytesRead, error) in
//                Log.debug("ReadLength after read: \(readLength), Bytes Read: \(bytesRead)")
                if error == nil
                {
                    self.read(buffer, length: readLength, callback: callback)
                } else {
                    callback?(length: bytesRead, error: error)
                }
            }
        }
    }
}