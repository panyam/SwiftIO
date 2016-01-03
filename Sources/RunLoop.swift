//
//  RunLoop.swift
//  SwiftIO
//
//  Created by Sriram Panyam on 12/24/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public protocol RunLoop
{
    /**
     * Starts the runloop
     */
    func start()
    /**
     * Stops the runloop
     */
    func stop()
    /**
     * Ensures that the block is performed within the runloop (if not already happening)
     */
    func ensure(block: () -> Void)
    /**
     * Enqueues a block to be run on the runloop.
     */
    func enqueue(block: () -> Void)
    /**
     * Enqueues a block to performed after a certain timeout in the future
     */
    func enqueueAfter(timeout: CFAbsoluteTime, block: Void -> Void)
}
