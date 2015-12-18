//
//  Streams.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/17/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public typealias BufferType = UnsafeMutablePointer<UInt8>
public typealias IOCallback = (buffer: BufferType?, length: Int?, error: ErrorType?) -> ()


public protocol Reader {
    func read(buffer: BufferType, length: Int, callback: IOCallback)
}

public protocol Writer {
    func write(buffer: BufferType, length: Int, callback: IOCallback?)
}

