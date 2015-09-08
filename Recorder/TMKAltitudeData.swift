//
//  TKMAltitudeData.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 21/3/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit
import CoreMotion

class TMKAltitudeData: NSObject {
    
    var relativeAltitude : Double = 0.0
    var pressure : Double = 0.0
    var timestamp : NSTimeInterval = 0.0
    override var description : String{
        return NSString(format: "Altitut %@ Pressio %@ Temps %f",self.relativeAltitude,self.pressure,self.timestamp) as String
    }

    
    
    //MARK: - Initializers
    
    
    internal override init(){
        
        super.init()
    }
    
    internal init(altitude: Double, pressure: Double, timestamp time: NSTimeInterval){
        
        self.relativeAltitude = altitude
        self.pressure = pressure
        self.timestamp = time
        
        super.init()
        
    }
    
    internal convenience init(CMAltitude alt : CMAltitudeData){
        
        self.init(altitude:alt.relativeAltitude.doubleValue,
            pressure:alt.pressure.doubleValue,
            timestamp: alt.timestamp)
        
    }
    
    internal convenience init(CMAltitudeNow alt:CMAltitudeData){
        self.init(altitude:alt.relativeAltitude.doubleValue,
            pressure:alt.pressure.doubleValue,
            timestamp: NSDate().timeIntervalSince1970)
        
    }
    
    internal func setDataWithAltitude(altitude: Double, pressure:Double, timestamp time:NSTimeInterval)
    {
        self.relativeAltitude = altitude
        self.pressure = pressure
        self.timestamp = time
    }
    
    
}
