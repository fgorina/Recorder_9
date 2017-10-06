//
//  AppState.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 27/9/15.
//  Copyright © 2015 Paco Gorina. All rights reserved.
//

import Foundation

enum appState : Int {
    case stopped = 0
    case recording
    case paused
}

enum appMode : Int {
    case localHR = 0
    case remoteHR
}
