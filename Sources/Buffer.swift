//
//  Buffer.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/18/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class Buffer {
    public class Slice
    {
        private var parent : Buffer?
        private var offset: Int = 0
        private var length: Int = 0
        
        public init(parent: Buffer, offset: Int, length: Int)
        {
            self.parent = parent
            self.offset = offset
            self.length = length
        }
    }

    private var parentSlice : Slice?
    private var bufferSize : Int
    private var data = [UInt8]()
    private var readOffset : Int = 0
    private var writeOffset : Int = 0
    
    public var length : Int {
        get {
            let delta = writeOffset - readOffset
            return delta > 0 ? delta : (capacity + delta)
        }
    }
    
    public var capacity : Int {
        get {
            return data.capacity
        }
    }

    public static func alloc(num: Int) -> Buffer
    {
        return Buffer(bufferSize: num)
    }
    
    public init (bufferSize: Int)
    {
        self.bufferSize = bufferSize
        self.data.reserveCapacity(bufferSize)
    }

    /**
     * Create a buffer as a slice of another buffer.
     */
    public init (parent: Buffer, offset: Int, length: Int)
    {
        self.parentSlice = Slice(parent: parent, offset: offset, length: length)
        self.bufferSize = -1
    }
    
    public func reset() {
        readOffset = 0
        writeOffset = 0
    }
}