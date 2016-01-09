//
//  IO.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/30/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public typealias LengthType = Int
public typealias OffsetType = LengthType
public typealias ReadBufferType = UnsafeMutablePointer<UInt8>
public typealias WriteBufferType = UnsafeMutablePointer<UInt8>
public typealias IOCallback = (length: LengthType, error: ErrorType?) -> Void
public typealias ResultCallback = (value : AnyObject?, error: ErrorType?) -> Void
public typealias CompletionCallback = (error: ErrorType?) -> Void

public enum IOErrorType : ErrorType
{
    /**
     * When the pipe has closed and no more read/write is possible
     */
    case Closed
    
    /**
     * When no more data is currently available on a read stream (a read would result in a block until data is available)
     */
    case Unavailable
}
