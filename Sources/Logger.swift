//
//  Logger.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 1/14/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import Foundation

public class Logger
{
    public enum LogLevel
    {
        case TRACE
        case DEBUG
        case INFO
        case WARNING
        case ERROR
        case CRITICAL
    }
    
    var dateFormatter : NSDateFormatter
    
    public init()
    {
        dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    public func log(level: LogLevel, _ str: String)
    {
        print("\(prefix(level))\(str)")
    }
    
    public func prefix(level: LogLevel) -> String {
        return "[\(level)] \(dateFormatter.stringFromDate(NSDate())) <\(NSThread.currentThread())>: "
    }
    
    public func trace(str: String) { log(.TRACE, str) }
    public func debug(str: String) { log(.DEBUG, str) }
    public func info(str: String) { log(.INFO, str) }
    public func warning(str: String) { log(.WARNING, str) }
    public func error(str: String) { log(.ERROR, str) }
    public func critical(str: String) { log(.CRITICAL, str) }
}

public let Log = Logger()