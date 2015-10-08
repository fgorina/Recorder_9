//
//  TGLTrackPointJSON.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 21/6/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreMotion

public extension NSMutableDictionary {

    
    public func setJSONPoint(trackPoint tp : TGLTrackPoint){
        
        let fmt = NSDateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let sdate = fmt.stringFromDate(tp.dtime)
        
        
        self.setValue(tp.coordinate.longitude, forKey: "lon")
        self.setValue(tp.coordinate.latitude, forKey: "lat")
        self.setValue(tp.ele, forKey: "ele")
        self.setValue(sdate, forKey: "time")
        self.setValue(tp.distanciaOrigen, forKey: "distanciaOrigen")
        self.setValue(tp.heartRate, forKey: "heartRate")
        self.setValue(0, forKey: "start")
        
        
        if tp is TMKWaypoint {
            self.setValue(2, forKey: "start")
        }
        
        
        if tp.distanciaOrigen < 0.1 {           // Goes over everything
            self.setValue(1, forKey: "start")
        }
    }
    

}