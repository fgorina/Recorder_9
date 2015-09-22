//
//  JSONMessage.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 21/6/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import Foundation
import UIKit

public class JSONMessage {
    
    var dispositivo : String        // Vendor ID del dispositiu
    var dades : NSArray             // Array de TGLTrackPointJSON
    var start = 0                   // Si 1 make new event
    
    public init(punts : NSArray){
        
        let uuid = UIDevice.currentDevice().identifierForVendor
        self.dispositivo = uuid!.UUIDString
        self.dades = punts
        
    }
    
    public func getJSONData() -> NSData? {
    
        do {
        let data : NSData? = try NSJSONSerialization.dataWithJSONObject(self, options: NSJSONWritingOptions())
        
    
        return data
        }
        catch _ {
            
        }
        
        let data : NSData? = nil
        
        return data
    
    }
    
    
}