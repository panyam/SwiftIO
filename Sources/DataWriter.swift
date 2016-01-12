//
//  DataWriter.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 1/3/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import Foundation

public class DataWriter
{
    private var writer : Writer
    
    public init (_ writer : Writer)
    {
        self.writer = writer
    }
    
    public func writeNBytes(numBytes : Int, _ value: Int, bigEndian: Bool, _ callback : CompletionCallback?)
    {
        print("Writing \(numBytes) bytes: \(value)")
        var numBytesLeft = numBytes
        while numBytesLeft > 0
        {
            let value : UInt8 = UInt8(truncatingBitPattern: ((value >> ((numBytesLeft - 1) * 8)) & 0xff))
            if numBytesLeft == 1
            {
                writer.write(value, callback)
            } else {
                writer.write(value, nil)
            }
            numBytesLeft -= 1
        }
    }
    
    public func writeInt8(value: Int8, callback : CompletionCallback?)
    {
        return writeNBytes(1, Int(value), bigEndian: true, callback)
    }
    public func writeInt16(value: Int16, callback : CompletionCallback?)
    {
        return writeNBytes(2, Int(value), bigEndian: true, callback)
    }
    public func writeInt32(value: Int32, callback : CompletionCallback?)
    {
        return writeNBytes(4, Int(value), bigEndian: true, callback)
    }
    public func writeInt64(value: Int64, callback : CompletionCallback?)
    {
        return writeNBytes(8, Int(value), bigEndian: true, callback)
    }
    
    public func writeUInt8(value: UInt8, callback : CompletionCallback?)
    {
        return writeNBytes(1, Int(value), bigEndian: true, callback)
    }
    public func writeUInt16(value: UInt16, callback : CompletionCallback?)
    {
        return writeNBytes(2, Int(value), bigEndian: true, callback)
    }
    public func writeUInt32(value: UInt32, callback : CompletionCallback?)
    {
        return writeNBytes(4, Int(value), bigEndian: true, callback)
    }
    public func writeUInt64(value: UInt64, callback : CompletionCallback?)
    {
        return writeNBytes(8, Int(value), bigEndian: true, callback)
    }
}
