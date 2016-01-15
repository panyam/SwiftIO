//
//  Buffer.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/18/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public let DEFAULT_BUFFER_LENGTH = 1024 * 1024

public class Buffer
{
    typealias BufferType = UnsafeMutablePointer<UInt8>
    private var bufferSize : LengthType = DEFAULT_BUFFER_LENGTH
    private var buffer : BufferType
    private var startOffset : OffsetType = 0
    private var endOffset : OffsetType = 0
    
    public var capacity : LengthType {
        return bufferSize
    }
    
    public var length: LengthType {
        get {
            let out = endOffset - startOffset
            return max(out, 0)
        }
    }

    public var isEmpty : Bool {
        get {
            return false
        }
    }
    
    public init(_ bufferSize: LengthType)
    {
        self.bufferSize = bufferSize
        self.buffer = BufferType.alloc(bufferSize)
    }
    
    public convenience init()
    {
        self.init(DEFAULT_BUFFER_LENGTH)
    }
    
    public func reset()
    {
        startOffset = 0
        endOffset = 0
    }
    
    /**
     * Copies data from a given buffer into this buffer.
     * Returns the number of bytes copied.
     */
//    public func assignFrom(buffer: UnsafePointer<UInt8>, count: LengthType) -> UInt8
//    {
//        assert(false, "Not yet implemented")
//    }
    
    /**
     * Advance the stream position by a given number of bytes.
     * This will be used by the consumer callback to continually update its status.
     */
    public func advanceBy(bytesConsumed: LengthType) -> UInt8
    {
        let out = buffer[startOffset]
        startOffset = min(startOffset + bytesConsumed, endOffset)
        if startOffset >= bufferSize
        {
            startOffset = endOffset
        }
        return out
    }
    
    /**
     * Return the buffer of the stream beginning at the current position.
     */
    var current : BufferType {
        return buffer.advancedBy(startOffset)
    }
    
    subscript(index: OffsetType) -> UInt8 {
        get {
            return buffer[startOffset + index]
        }
    }
    
    public func read(reader: Reader, callback: IOCallback?)
    {
        if startOffset == endOffset
        {
            startOffset = 0
            endOffset = 0
        }
        
        // TODO: see if needs resizing or moving or circular management
        assert(bufferSize > endOffset, "Needs some work here!")
        reader.read(current, length: bufferSize - endOffset) { (length, error) in
            if error == nil {
                self.endOffset += length
                if self.endOffset > self.bufferSize
                {
                    self.endOffset = 0
                }
            }
            callback?(length: length, error: error)
        }
    }
}
