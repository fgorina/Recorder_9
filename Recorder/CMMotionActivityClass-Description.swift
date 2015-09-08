//
//  CMMotionActivityClass-Description.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 26/4/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import CoreMotion

public enum ActivityEnum {
    case Unknown
    case Stationary
    case Walking
    case Running
    case Cycling
    case Automotive
}

extension CMMotionActivity {
    
    public func activEnum() -> ActivityEnum {
        if self.walking{
            return ActivityEnum.Walking
        }
        if self.running{
            return ActivityEnum.Running
        }
        if self.cycling{
            return ActivityEnum.Cycling
        }
        if self.automotive{
            return ActivityEnum.Automotive
        }
        if self.stationary{
            return ActivityEnum.Stationary
        }
        return ActivityEnum.Unknown
    }
    
    public var stringDescription : String {
        return CMMotionActivity.activityDescription(self.activEnum())
    }
    
    class public func activityDescription (activ : ActivityEnum) -> String{
        
        switch activ{
        case .Stationary : return "Stationary"
        case .Walking : return "Walking"
        case .Running : return "Running"
        case .Cycling : return "Cycling"
        case .Automotive : return "Automotive"
        default : return "Unknown"
        }
        
    }
    
    class public func activityFromString(str : String) -> ActivityEnum {
        
        switch str {
        case "Stationary" : return .Stationary
        case "Walking" : return .Walking
        case "Running" : return .Running
        case "Cycling" : return .Cycling
        case "Automotive" : return .Automotive
        default: return .Unknown
            
        }
        
        
    }
    
    
}
