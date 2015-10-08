//
//  InterfaceController.swift
//  WatchApp Extension
//
//  Created by Francisco Gorina Vanrell on 22/9/15.
//  Copyright © 2015 Paco Gorina. All rights reserved.
//

import Foundation
import WatchKit
import WatchConnectivity
import HealthKit



class WAInterfaceController: WKInterfaceController {
    
    //MARK: UI elements
    
    @IBOutlet weak  var startButton : WKInterfaceButton!
    @IBOutlet weak  var workoutTimer :WKInterfaceTimer!
    @IBOutlet weak  var lapTimer : WKInterfaceTimer!
    @IBOutlet weak  var distLabel : WKInterfaceLabel!
    //@IBOutlet weak  var hrCounterLabel : WKInterfaceLabel!
    @IBOutlet weak  var distLapLabel : WKInterfaceLabel!
    
    @IBOutlet weak var sessionOnLabel : WKInterfaceImage!
    
    //MARK: State
    
    
    var distancia : Double? = 0
    var startTime : NSDate?
    var ascent : Double? = 0
    var descent : Double? = 0
    var altura : Double? = 0
    
    var wStartTime : NSDate?
    var wDistancia : Double? = 0
    var wAscent : Double? = 0
    var wDescent : Double? = 0
    
    var state : appState = .Stopped
    
    var counter : Int = 0
   
    //MARK: Other properties
    
    var query : HKQuery?
    
    var wcsession : WCSession? = WCSession.defaultSession()

    
    // Heart Rate Follow
   
    let heartRateUnit = HKUnit(fromString: "count/min")
    var anchor = HKQueryAnchor(fromValue: Int(HKAnchoredObjectQueryNoAnchor))
    
    
    //MARK: Controller Life Cicle
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        
        if let session = wcsession{
            session.delegate = self
            session.activateSession()
            
        }

        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    //MARK: User Actions
    
    @IBAction func start()
    {
        /// Do start function with Recorder
        
        self.workoutTimer.setDate(NSDate())
        self.workoutTimer.start()
        
        self.lapTimer.setDate(NSDate())
        self.lapTimer.start()
        
        // Try to send a message with start order to iPhone application
        
        self.sendOp("start" , value:nil)
        
    }
    
    @IBAction func stop()
    {
        /// Do start function with Recorder
        
        self.workoutTimer.stop()
        self.lapTimer.stop()
        
        // Try to send a message with start order to iPhone application
        
        self.sendOp("stop" , value:nil)
        
    }
    
    @IBAction func pause()
    {
        /// Do start function with Recorder
        
        self.workoutTimer.stop()
        self.lapTimer.stop()
        
        // Try to send a message with start order to iPhone application
        
        self.sendOp("pause", value:nil)
        
    }
    
    //MARK: iOS Communication
    
    func sendOp(op : String, value : AnyObject?){
        if let session = self.wcsession{
            
            if session.reachable {
                
                var dict : [String : AnyObject] = ["op" : op]
                if let v = value {
                    dict["value"] = v
                }
                session.sendMessage(dict, replyHandler: nil, errorHandler: { (err : NSError) -> Void in
                    
                    NSLog("Error al enviar missatge %@", err)
                })
            }
        }
    }
    
    
    func sendData(object: [HKQuantitySample]){
        
         if let session = self.wcsession{
        
            let data : NSData = NSKeyedArchiver.archivedDataWithRootObject(object)
            
            session.sendMessageData(data, replyHandler: nil, errorHandler: { (err : NSError) -> Void in
                NSLog("Error al enviar dades %@", err)
            })
        }
     }
    
    
    func updateData(applicationContext: [String : AnyObject]){
        
        if let rawState = applicationContext["state"] as? Int{
            if let newState = appState(rawValue: rawState){
                
                if self.state == .Stopped && newState == .Recording {
                    self.startRecording()
                }
                else if self.state != .Stopped && newState == .Stopped {
                    self.stopRecording()
                }
                
                self.state = newState
            }
        }
        distancia = applicationContext["distancia"] as? Double
        startTime = applicationContext["startTime"] as? NSDate
        ascent = applicationContext["ascent"] as? Double
        descent = applicationContext["descent"] as? Double
        altura = applicationContext["altura"] as? Double
        
        wDistancia = applicationContext["wDistancia"] as? Double
        wStartTime = applicationContext["wStartTime"] as? NSDate
        wAscent = applicationContext["wAscent"] as? Double
        wDescent = applicationContext["wDescent"] as? Double

        
        updateFields()
        
    }
    
    
    //MARK: Internal actions
    
    func startRecording(){
        
        // Start Workout Session
        
        if let hs =  (WKExtension.sharedExtension().delegate as? ExtensionDelegate)?.healthStore{
            
            // If in a WK Session close it
            
            if let wsession = (WKExtension.sharedExtension().delegate as? ExtensionDelegate)?.wkSession {
                
                if wsession.state == .Running {
                    hs.endWorkoutSession(wsession)
                }
            }
            
            // Create a new one
            
            let wsession = HKWorkoutSession(activityType:HKWorkoutActivityType.Running, locationType:HKWorkoutSessionLocationType.Outdoor)
            wsession.delegate = self
            
            hs.startWorkoutSession(wsession)
            
            if let del = WKExtension.sharedExtension().delegate as? ExtensionDelegate{
                del.wkSession = wsession
            }
        }
    }
    
    
    
    func stopRecording(){
        
        // Stop Workout Session
        
        if let wsession = (WKExtension.sharedExtension().delegate as? ExtensionDelegate)?.wkSession, hs =  (WKExtension.sharedExtension().delegate as? ExtensionDelegate)?.healthStore {
            
            if wsession.state == .Running {
                hs.endWorkoutSession(wsession)
            }
        }
    }
    
    //MARK: Update Screen data
    
    
    func updateFields(){
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            
            
            if let time = self.startTime {
                self.workoutTimer.setDate(time)
                if self.state == .Recording{
                    self.workoutTimer.start()
                }
                else{
                    self.workoutTimer.stop()
                }
            }
            
            if let time = self.wStartTime {
                self.lapTimer.setDate(time)
                if self.state == .Recording{
                    self.lapTimer.start()
                }
                else{
                    self.lapTimer.stop()
                }
            }

            
            if let v = self.distancia {
                if v < 1000.0 {
                    
                    let units = "m"
                    self.distLabel.setText(String(format: "%3.0f%@", v, units))
                }
                else{
                    let units = "Km"
                    self.distLabel.setText(String(format: "%5.2f%@", v/1000.0, units))
                }
  
            }
            
            if let v = self.wDistancia {
                if v < 1000.0 {
                    
                    let units = "m"
                    self.distLapLabel.setText(String(format: "%3.0f%@", v, units))
                }
                else{
                    let units = "Km"
                    self.distLapLabel.setText(String(format: "%5.2f%@", v/1000.0, units))
                }
                
            }

            
            var stateIcon = "record_64"
            
            switch self.state{
                
            case .Stopped:
                stateIcon = "record_64"
                self.startButton.setBackgroundImageNamed(stateIcon)
                
            case .Paused:
                stateIcon = "pause_64"
                self.startButton.setBackgroundImageNamed(stateIcon)
                
            case .Recording:
                stateIcon = "record_wp_64"
                self.startButton.setBackgroundImage(nil)
            }
            
            
        })
    }
}

//MARK: WCSessionDelegate

extension WAInterfaceController : WCSessionDelegate{
    
    func sessionWatchStateDidChange(session: WCSession) {
        
        NSLog("WCSessionState changed. Reachable %@", session.reachable)
    }
    
    func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]){

        self.updateData(applicationContext)
    }
}



//MARK: HKWorkoutSessionDelegate

extension WAInterfaceController : HKWorkoutSessionDelegate{
    
    func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate) {
        
       // NSLog("WKSession state %@ -> %@", fromState.rawValue, toState.rawValue )
        
        switch toState {
        case .Running:
            workoutDidStart(date)
        case .Ended:
            workoutDidEnd(date)
        default:
            print("Unexpected state \(toState)")
        }
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didFailWithError error: NSError) {
        // Do nothing for now
        
        NSLog("Error en workoutSession %@ - %@", workoutSession, error)
    }
    
    
//MARK: HKWorkoutSessionDelegate Auxiliary Functions
    
    
    func workoutDidStart(date : NSDate) {
        
        self.sessionOnLabel.setHidden(false)
        
        if let healthStore = (WKExtension.sharedExtension().delegate as? ExtensionDelegate)?.healthStore {
            if let q = createHeartRateStreamingQuery(date) {
                self.query = q
                healthStore.executeQuery(q)
            } else {
                self.startButton.setTitle("?")
            }
        }
    }
    
    func workoutDidEnd(date : NSDate) {
        
        self.sessionOnLabel.setHidden(true)
        
          if let healthStore = (WKExtension.sharedExtension().delegate as? ExtensionDelegate)?.healthStore {
            if let q = self.query {
                healthStore.stopQuery(q)
                self.startButton.setTitle("")
            } else {
                self.startButton.setTitle("??")
            }
        }
    }
    
    

    func createHeartRateStreamingQuery(workoutStartDate: NSDate) -> HKQuery? {
        // adding predicate will not work
        // let predicate = HKQuery.predicateForSamplesWithStartDate(workoutStartDate, endDate: nil, options: HKQueryOptions.None)
        
        guard let quantityType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate) else { return nil }
        
        let predicate = HKQuery.predicateForSamplesWithStartDate(NSDate(), endDate: nil, options: HKQueryOptions.None)
        
        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType, predicate: predicate, anchor: anchor, limit: Int(HKObjectQueryNoLimit)) { (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            guard let newAnchor = newAnchor else {return}
            self.anchor = newAnchor
            self.updateHeartRate(sampleObjects)
        }
        
        heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            self.anchor = newAnchor!
            self.updateHeartRate(samples)
        }
        return heartRateQuery
    }
    
    
    func updateHeartRate(samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        
        dispatch_async(dispatch_get_main_queue()) {
            guard let sample = heartRateSamples.first else{return}
            let value = sample.quantity.doubleValueForUnit(self.heartRateUnit)
            //self.label.setText(String(UInt16(value)))
            
            self.startButton.setTitle(String(UInt16(value)))
            self.sendData(heartRateSamples)
            self.counter += heartRateSamples.count
           // self.hrCounterLabel.setText(String(self.counter))
            
            // retrieve source from sample
            //let name = sample.sourceRevision.source.name
            //self.updateDeviceName(name)
            //self.animateHeart()
        }
    }
}
