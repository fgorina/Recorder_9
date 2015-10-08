//
//  ExtensionDelegate.swift
//  WatchApp Extension
//
//  Created by Francisco Gorina Vanrell on 22/9/15.
//  Copyright © 2015 Paco Gorina. All rights reserved.
//

import WatchKit
import WatchConnectivity
import HealthKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    
    var healthStore : HKHealthStore?
    var wkSession : HKWorkoutSession?
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        
        if HKHealthStore.isHealthDataAvailable() {
            self.requestAuthorization()
        }
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }
    
    
    
//MARK: HealhtStore
    
    func getTypesForIdentifiers(identifiers: [String]) -> Set<HKSampleType>{
        
        var types : Set<HKSampleType> = Set<HKSampleType>()
        
        
        for v in identifiers{
            let d = HKSampleType.quantityTypeForIdentifier(v)
            if let dok = d{
                types.insert(dok)
            }
        }
        
        types.insert(HKWorkoutType.workoutType())
        
        
        return types
        
    }
    
    
    func requestAuthorization(){
        
        let dataTypes = [HKQuantityTypeIdentifierHeartRate, HKQuantityTypeIdentifierFlightsClimbed, HKQuantityTypeIdentifierDistanceWalkingRunning]
        
        let types = self.getTypesForIdentifiers(dataTypes)
        
        self.healthStore = HKHealthStore()
        
        if let hs = self.healthStore{
            
            hs.requestAuthorizationToShareTypes(nil , readTypes: types, completion: { (success:Bool, err:NSError?) -> Void in
                if !success{
                    if let error = err {
                    NSLog("Error al demanar autorizacio %@", error)
                    }
                }
            })
        }
    }
    
}

