//
//  Writer.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 1/3/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import Foundation

public protocol Writer {
    /**
     * The stream associated this writer is producing to.
     */
    var stream : Stream { get }
    
    func flush(callback: CompletionCallback?)
    func write(value : UInt8, _ callback: CompletionCallback?)
    func write(buffer: WriteBufferType, length: LengthType, _ callback: IOCallback?)
}

public extension Writer {
    public func writeString(string: String)
    {
        writeString(string, nil)
    }
    
    public func writeString(string: String, _ callback: IOCallback?)
    {
        let nsString = string as NSString
        let length = nsString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        write(WriteBufferType(nsString.UTF8String), length: LengthType(length), callback)
    }
}
