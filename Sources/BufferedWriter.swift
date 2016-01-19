//
//  BufferedWriter.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 1/16/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import Foundation

public class BufferedWriter : Writer {
    public var writer : Writer
    private var dataBuffer : Buffer
    private var bufferSize : LengthType = 0
    
    public init (_ writer: Writer, bufferSize: LengthType)
    {
        self.writer = writer
        self.bufferSize = bufferSize
        self.dataBuffer = Buffer(bufferSize)
    }
    
    public convenience init (_ writer: Writer)
    {
        self.init(writer, bufferSize: DEFAULT_BUFFER_LENGTH)
    }
    
    public var stream : Stream {
        return writer.stream
    }
    
    public func flush()
    {
    }

    public func write(value : UInt8, _ callback: CompletionCallback?)
    {
        if !dataBuffer.isFull
        {
            dataBuffer.write(value)
            callback?(error: nil)
        } else {
            // flush it write later
            let oldBuffer = dataBuffer
            dataBuffer = Buffer(bufferSize)
            oldBuffer.write(writer, callback: nil)
            write(value, callback)
        }
    }
    
    public func write(buffer: WriteBufferType, length: LengthType, _ callback: IOCallback?)
    {
    }
}