//
//  NSMutableArray+Queues.swift
//  Recorder
//
//  Utilitat per gestionar cues sincronitzades
//
//  Created by Francisco Gorina Vanrell on 21/6/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import Foundation

extension NSMutableArray{
    
    func enqueue(obj : AnyObject){
        
        objc_sync_enter(self);
        self.addObject(obj);
        objc_sync_exit(self);
    }
    
    func dequeue() -> AnyObject?{
        
        var o : AnyObject?
        
        objc_sync_enter(self)
        
        if let ob: AnyObject = self.firstObject{
            o = ob
            self.removeObjectAtIndex(0)
        }
        objc_sync_exit(self)
        
        return o
    }
    
    func push(obj : AnyObject){
        objc_sync_enter(self);
        self.insertObject(obj, atIndex: 0)
        objc_sync_exit(self);
    }
    
    func pop() -> AnyObject?{
        return dequeue()
    }
    
}