//
//  GlobalConstants.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 2/10/15.
//  Copyright © 2015 Paco Gorina. All rights reserved.
//

import Foundation

struct GlobalConstants {
    static let debug = false
    static let debugLaunch = false
}

func debugMsg(_ str : String){
    if GlobalConstants.debug{
        NSLog(str)
    }
}

func debugLaunch(_ str : String){
    if GlobalConstants.debugLaunch{
        NSLog(str)
    }
}
