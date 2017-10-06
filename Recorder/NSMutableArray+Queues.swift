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
    
    func enqueue(_ obj : AnyObject){
        
        objc_sync_enter(self);
        self.add(obj);
        objc_sync_exit(self);
    }
    
    func dequeue() -> AnyObject?{
        
        var o : AnyObject?
        
        objc_sync_enter(self)
        
        if let ob: AnyObject = self.firstObject as AnyObject?{
            o = ob
            self.removeObject(at: 0)
        }
        objc_sync_exit(self)
        
        return o
    }
    
    func push(_ obj : AnyObject){
        objc_sync_enter(self);
        self.insert(obj, at: 0)
        objc_sync_exit(self);
    }
    
    func pop() -> AnyObject?{
        return dequeue()
    }
    
}
