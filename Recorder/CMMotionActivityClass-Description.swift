//
//  CMMotionActivityClass-Description.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 26/4/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import CoreMotion

public enum ActivityEnum : Int{
    case unknown = 0
    case stationary
    case walking
    case running
    case cycling
    case automotive
}

extension CMMotionActivity {
    
    public func activEnum() -> ActivityEnum {
        if self.walking{
            return ActivityEnum.walking
        }
        if self.running{
            return ActivityEnum.running
        }
        if self.cycling{
            return ActivityEnum.cycling
        }
        if self.automotive{
            return ActivityEnum.automotive
        }
        if self.stationary{
            return ActivityEnum.stationary
        }
        return ActivityEnum.unknown
    }
    
    public var stringDescription : String {
        return CMMotionActivity.activityDescription(self.activEnum())
    }
    
    class public func activityDescription (_ activ : ActivityEnum) -> String{
        
        switch activ{
        case .stationary : return "Stationary"
        case .walking : return "Walking"
        case .running : return "Running"
        case .cycling : return "Cycling"
        case .automotive : return "Automotive"
        default : return "Unknown"
        }
        
    }
    
    class public func activityFromString(_ str : String) -> ActivityEnum {
        
        switch str {
        case "Stationary" : return .stationary
        case "Walking" : return .walking
        case "Running" : return .running
        case "Cycling" : return .cycling
        case "Automotive" : return .automotive
        default: return .unknown
            
        }
        
        
    }
    
    
}
