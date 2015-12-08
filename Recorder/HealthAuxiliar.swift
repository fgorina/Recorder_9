//
//  HealthAuxiliar.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 11/11/15.
//  Copyright © 2015 Paco Gorina. All rights reserved.
//

import Foundation
import HealthKit


class HealthAuxiliar {
    
    var enable : Bool = true
    
    var healthStore : HKHealthStore?
    var age : Int?
    var maleSex : Bool?
    var height : Double?
    var weight : Double?
    var maxHR : Double? = 174.0
    var minHR : Double? = 45.0
    var vo2Max : Double? = 55.0
    
    
    let heightType = HKSampleType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeight)
    let weightType = HKSampleType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)
    
 
    
    init(){
        
        
        let store = NSUserDefaults.standardUserDefaults()
        var sval : Double = 0.0
        
        sval = Double(store.integerForKey("minHR"))
        if sval != 0.0 {
            minHR = sval
        }
        
        sval = Double(store.integerForKey("maxHR"))
        if sval != 0.0 {
            maxHR = sval
        }

        sval = store.doubleForKey("vo2max")
        if sval != 0.0 {
            vo2Max = sval
        }

        
        
        if self.enable &&  HKHealthStore.isHealthDataAvailable(){
            
            self.requestAuthorization()
            
        }
        
        
    }
    
    func isHealthEnabled() -> Bool{
        
        return enable && healthStore != nil
        
    }
    
    //MARK: HKHealthStore related
    
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
        
        let dataTypes = [HKQuantityTypeIdentifierHeartRate, HKQuantityTypeIdentifierFlightsClimbed, HKQuantityTypeIdentifierDistanceWalkingRunning, HKQuantityTypeIdentifierBodyMass,
            HKQuantityTypeIdentifierHeight, HKQuantityTypeIdentifierActiveEnergyBurned]
        
        let types = self.getTypesForIdentifiers(dataTypes)
        var otypes = self.getTypesForIdentifiers(dataTypes) as Set<HKObjectType>
        
        otypes.insert(HKSampleType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierBiologicalSex)! )
        otypes.insert(HKSampleType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierDateOfBirth)! )
        
        let hs = HKHealthStore()
        
        hs.requestAuthorizationToShareTypes(types , readTypes: otypes, completion: { (success:Bool, err:NSError?) -> Void in
            if success {
                self.healthStore = hs
                
                self.readProfile()
                
            }
            else{
                if let error = err {
                    NSLog("Error al demanar autorizacio %@", error)
                }
            }
        })
        
    }
    
    
    //MARK: Access needed personal data

    func readProfile()
    {
        if let hs = self.healthStore{
        
        
        // 1. Request birthday and calculate age
        do {
            let birthDay = try hs.dateOfBirth()
            let today = NSDate()
            let differenceComponents = NSCalendar.currentCalendar().components(.Year, fromDate: birthDay, toDate: today, options:[])
            age = differenceComponents.year
        }
        catch   {
            
        }
        
        
        // 2. Read biological sex
        do {
            
            let bs =  try hs.biologicalSex()
            
            switch bs.biologicalSex {
            case .Male :
                maleSex = true
                
            case .Female :
                maleSex = false
                
            default:
                break
            }
        }
        catch let error{
            
            let err = error as NSError
            
                NSLog("Error al %@ llegir bilogical sex", err)
            
            
        }
            self.readMostRecentSample(hs, sampleType: self.heightType!) { (sample:HKSample!, error:NSError!) -> Void in
                
                if error == nil{
                    if let qs = sample as? HKQuantitySample{
                        self.height = qs.quantity.doubleValueForUnit(HKUnit(fromString: "cm"))
                    }
                }
            }
            
            
            self.readMostRecentSample(hs, sampleType: self.weightType!) { (sample:HKSample!, error:NSError!) -> Void in
                if error == nil{
                    if let qs = sample as? HKQuantitySample{
                        self.weight = qs.quantity.doubleValueForUnit(HKUnit(fromString: "kg"))
                    }
                }
            }
        }
     }
    

    
    func readMostRecentSample(healthStore : HKHealthStore, sampleType:HKSampleType , completion: ((HKSample!, NSError!) -> Void)!)
    {
        
        // 1. Build the Predicate
        let past = NSDate.distantPast()
        let now   = NSDate()
        let mostRecentPredicate = HKQuery.predicateForSamplesWithStartDate(past, endDate:now, options: .None)
        
        // 2. Build the sort descriptor to return the samples in descending order
        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)
        // 3. we want to limit the number of samples returned by the query to just 1 (the most recent)
        let limit = 1
        
        // 4. Build samples query
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: mostRecentPredicate, limit: limit, sortDescriptors: [sortDescriptor])
            { (sampleQuery, results, error ) -> Void in
                
                if let queryError = error {
                    completion(nil,queryError)
                    return
                }
                
                // Get the first sample
                
                if let res = results{
                    let mostRecentSample = res.first as? HKQuantitySample
                    
                    // Execute the completion closure
                    if completion != nil {
                        completion(mostRecentSample,nil)
                    }
                    
                }
        }
        // 5. Execute the Query
        healthStore.executeQuery(sampleQuery)
    }
    
    //MARK: Get Calories for work
    
    
    func calories(hr : Double, duracio : NSTimeInterval) -> (total: Double, activ: Double) {
        
        // Check all data needed is OK
        
        if age != nil  && weight != nil && height != nil {
            
            var sex = false     // By default if sex is not defined sex = female
            
            if maleSex != nil {
                sex = self.maleSex!
            }

            return HealthAuxiliar.computeCaloriesFromHR(hr, vo2max: self.vo2Max, height: self.height!, weight: self.weight!, age: Double(self.age!), duracio: duracio, sexMale: sex)
        }
        
        return (-1.0, -1.0)
        
    }
    
    //MARK: Supporting calories calculations
    //
    // Formules from http://www.shapesense.com/fitness-exercise/calculators/heart-rate-based-calorie-burn-calculator.aspx
    
    
    // hr in b/min
    // weight in kg
    // age in years
    // duration in seconds
    // sex : male = true, female = false -> Canviar a unes opcions
    
    
    class func computeCaloriesFromHR(hr : Double, vo2max : Double? , height: Double, weight : Double, age : Double , duracio : NSTimeInterval, sexMale : Bool) -> (Double, Double){
        
        let hours = duracio / 3600.0
        
        var cals = 0.0
        
        if let vo2 = vo2max {
        
            if sexMale {
                cals = ((-95.7735 + ( 0.634 * hr) + (0.404 * vo2) + (0.394 * weight) + (0.271 * age)) / 4.184) * 60.0 * hours
            }
            else{
                cals = ((-59.3954 + ( 0.45 * hr) + (0.380 * vo2) + (0.103 * weight) + (0.274 * age)) / 4.184) * 60.0 * hours
            }
        }
        else{
            if sexMale {
                cals = ((-55.0969 + ( 0.6309 * hr)  + (0.1988 * weight) + (0.2017 * age)) / 4.184) * 60.0 * hours
            }
            else{
                cals = ((-20.4022 + ( 0.4472 * hr) - (0.1163 * weight) + (0.074 * age)) / 4.184) * 60.0 * hours
            }

        }
        
        let activeCals = cals - HealthAuxiliar.rmrcb(weight, height:height, age: age, sexMale: sexMale, duration:duracio)
        return (cals, activeCals)
        
    }
    
    
    
    
    
    
    class func maxHeartRate(age : Double) -> Double {
        return 208 - (0.7 * age)
    }
    
    class func percentVo2maxFromMaxHR(heartRate : Double , maxHeartRate : Double) -> Double {
        return 1.5472 * (heartRate / maxHeartRate) * 100 - 57.53
    }
    
    class func bmr(weight : Double, height : Double, age : Double, sexMale : Bool) -> Double {
        
        if sexMale {
            return (13.75 * weight) + (5 * height) - (6.76 * age) + 66
        }
        else {
            return (9.56 * weight) + (1.85 * height) - (4.68 * age) + 66
        }
        
    }
    
    class func rmrcb(weight : Double, height : Double, age : Double, sexMale : Bool, duration: NSTimeInterval)->Double{
        
        return (bmr(weight, height: height, age: age, sexMale: sexMale) * 1.1) / 86400.0 * duration
    }

    
}