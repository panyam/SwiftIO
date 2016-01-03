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

public enum IOErrorType : ErrorType
{
    /**
     * When the pipe has closed and no more read/write is possible
     */
    case Closed

    /**
     * When the end of a stream has been reached and no more data can be read or written.
     */
    case EndReached
    
    /**
     * When no more data is currently available on a read stream (a read would result in a block until data is available)
     */
    case Unavailable
    
    public func equals(error: ErrorType?) -> Bool
    {
        if error == nil
        {
            return false
        }
        
        if let ioError = error as? IOErrorType
        {
            return ioError == self
        }
        return false
    }
}
