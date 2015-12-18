//
//  ErrorTypes.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/16/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation


public class SocketErrorType : ErrorType
{
    public var domain : String = ""
    public var code : Int32 = 0
    public var message : String = ""
    public var data : AnyObject?
    
    public init(domain : String, code: Int32, message: String, data: AnyObject?)
    {
        self.domain = domain
        self.code = code
        self.message = message
        self.data = data
    }
    
    public convenience init(domain : String, code: Int32, message: String)
    {
        self.init(domain: domain, code: code, message: message, data: nil)
    }
    
    public convenience init(message: String)
    {
        self.init(domain: "", code: 0, message: message)
    }
}
