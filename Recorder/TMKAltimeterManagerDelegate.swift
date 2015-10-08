//
//  TMKAltimeterDelegateProtocol.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 25/9/15.
//  Copyright © 2015 Paco Gorina. All rights reserved.
//

import Foundation
import CoreMotion
import MapKit


protocol TMKAltimeterManagerDelegate {
    // protocol definition goes here
    
    func updateActivity(activity: CMMotionActivity)
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    func updateTrackPoints(dat : [TGLTrackPoint])

    
}