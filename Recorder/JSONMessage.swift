//
//  JSONMessage.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 21/6/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import Foundation
import UIKit

open class JSONMessage {
    
    var dispositivo : String        // Vendor ID del dispositiu
    var dades : NSArray             // Array de TGLTrackPointJSON
    var start = 0                   // Si 1 make new event
    
    public init(punts : NSArray){
        
        let uuid = UIDevice.current.identifierForVendor
        self.dispositivo = uuid!.uuidString
        self.dades = punts
        
    }
    
    open func getJSONData() -> Data? {
    
        do {
        let data : Data? = try JSONSerialization.data(withJSONObject: self, options: JSONSerialization.WritingOptions())
        
    
        return data
        }
        catch _ {
            
        }
        
        let data : Data? = nil
        
        return data
    
    }
    
    
}
