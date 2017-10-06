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
    @IBOutlet weak  var hrLabel : WKInterfaceLabel!
    @IBOutlet weak  var unitsLabel : WKInterfaceLabel!
    @IBOutlet weak  var climbingLabel : WKInterfaceLabel!
    //@IBOutlet weak  var hrCounterLabel : WKInterfaceLabel!
    @IBOutlet weak  var distLapLabel : WKInterfaceLabel!
    
    @IBOutlet weak var sessionOnLabel : WKInterfaceImage!
    
    //MARK: State
    
    
    var distancia : Double? = 0
    var startTime : Date?
    var ascent : Double? = 0
    var descent : Double? = 0
    var ascentSpeed : Double? = 0
    var descentSpeed : Double? = 0
    var altura : Double? = 0
    var speed : Double? = 0
    var hr : Int = 0
    
    var wStartTime : Date?
    var wDistancia : Double? = 0
    var wAscent : Double? = 0
    var wDescent : Double? = 0
    
    
    var state : appState = .stopped
    
    var counter : Int = 0
    
    var stateChanged = false
    
    var localMode : appMode = .remoteHR
    
    
    //MARK: Other properties
    
    var query : HKQuery?
    
    var wcsession : WCSession? = WCSession.default()
    
    
    // Heart Rate Follow
    
    let heartRateUnit = HKUnit(from: "count/min")
    var anchor = HKQueryAnchor(fromValue: Int(HKAnchoredObjectQueryNoAnchor))
    
    // Navigation
    
    var actualPageController : WAInterfaceNavigation?
    
    
    //MARK: Controller Life Cicle
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        self.actualPageController = self
        
        if let session = wcsession{
            session.delegate = self
            session.activate()
            
        }
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        self.actualPageController = self;
        self.updateFields()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    //MARK: User Actions
    
    @IBAction func start()
    {
        
        
        /// Do start function with Recorder
        
        if self.state == .stopped {
            
            // Reset all to 0's
            
            let d = Date()
            self.workoutTimer.setDate(d)
            self.workoutTimer.start()
            
            self.lapTimer.setDate(d)
            self.lapTimer.start()
            
            // Set all data to 0
            
            self.distancia = 0.0
            self.startTime = d
            self.ascent = 0.0
            self.descent = 0.0
            self.ascentSpeed = 0.0
            self.descentSpeed = 0.0
            self.altura = 0.0
            self.speed  = 0.0
            self.hr = 0
            
            self.wStartTime = d
            self.wDistancia = 0.0
            self.wAscent = 0.0
            self.wDescent  = 0.0

            updateScreenFields()
            
            // Try to send a message with start order to iPhone application
            
            self.sendOp("start" , value:nil)
            
            
        }
        else {
            self.lapTimer.setDate(Date())
            self.lapTimer.start()
            self.sendOp("waypoint" , value:nil)
        }
        
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
        
       // self.workoutTimer.stop()
        // self.lapTimer.stop()
        
        // Try to send a message with start order to iPhone application
        
        self.sendOp("pause", value:nil)
        
    }
    
    //MARK: iOS Communication
    
    func sendOp(_ op : String, value : AnyObject?){
        if let session = self.wcsession{
            
            if session.isReachable {
                
                var dict : [String : AnyObject] = ["op" : op as AnyObject]
                if let v = value {
                    dict["value"] = v
                }
                session.sendMessage(dict, replyHandler: nil, errorHandler: { (err : Error) -> Void in
                    let error : NSError = err as NSError
                    NSLog("Error al enviar missatge %@", error)
                    
                })
            }
        }
    }
    
    
    func sendData(_ object: [HKQuantitySample]){
        
        if let session = self.wcsession{
            
            let data : Data = NSKeyedArchiver.archivedData(withRootObject: object)
            
            session.sendMessageData(data, replyHandler: nil, errorHandler: { (err : Error) -> Void in
                let error : NSError = err as NSError
                NSLog("Error al enviar dades %@", error)
            })
        }
    }
    
    
    func updateData(_ applicationContext: [String : AnyObject]){
        
        if let rawState = applicationContext["state"] as? Int{
            if let newState = appState(rawValue: rawState){
                
                if self.state == .stopped && newState == .recording {
                    self.startRecording()
                }
                else if self.state != .stopped && newState == .stopped {
                    self.stopRecording()
                }
                
                if self.state != newState {
                    self.state = newState
                    self.stateChanged = true
                }
            }
        }
        distancia = applicationContext["distancia"] as? Double
        startTime = applicationContext["startTime"] as? Date
        ascent = applicationContext["ascent"] as? Double
        descent = applicationContext["descent"] as? Double
        ascentSpeed = applicationContext["ascentSpeed"] as? Double
        descentSpeed = applicationContext["descentSpeed"] as? Double
        altura = applicationContext["altura"] as? Double
        speed = applicationContext["speed"] as? Double
        
        if let dhr = applicationContext["HR"] as? Int{
            hr = dhr
        }
        
        wDistancia = applicationContext["wDistancia"] as? Double
        wStartTime = applicationContext["wStartTime"] as? Date
        wAscent = applicationContext["wAscent"] as? Double
        wDescent = applicationContext["wDescent"] as? Double
        
        
        
        
        updateScreenFields()
    }
    
    
    //MARK: Internal actions
    
    func startRecording(){
        
        // Start Workout Session
        
        if let hs =  (WKExtension.shared().delegate as? ExtensionDelegate)?.healthStore{
            
            // If in a WK Session close it
            
            if let wsession = (WKExtension.shared().delegate as? ExtensionDelegate)?.wkSession {
                
                if wsession.state == .running {
                    hs.end(wsession)
                }
            }
            
            // Create a new one only if my preference is local
            
            if self.localMode == appMode.localHR{
                
                let wsession = HKWorkoutSession(activityType:HKWorkoutActivityType.running, locationType:HKWorkoutSessionLocationType.outdoor)
                wsession.delegate = self
                
                hs.start(wsession)
                
                if let del = WKExtension.shared().delegate as? ExtensionDelegate{
                    del.wkSession = wsession
                }
            }
        }
    }
    
    
    
    func stopRecording(){
        
        // Stop Workout Session
        
        if let wsession = (WKExtension.shared().delegate as? ExtensionDelegate)?.wkSession, let hs =  (WKExtension.shared().delegate as? ExtensionDelegate)?.healthStore {
            
            if wsession.state == .running {
                hs.end(wsession)
            }
        }
    }
    
    func updateScreenFields(){
        
        if self.actualPageController == nil {
            self.actualPageController = self
        }
        
        self.actualPageController!.updateFields()
    }
    
    
}

//MARK: WCSessionDelegate

extension WAInterfaceController : WCSessionDelegate{
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    @available(watchOS 2.2, *)
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        
    }

    
//    func sessionWatchStateDidChange(_ session: WCSession) {
//
//        NSLog("WCSessionState changed. Reachable %@", session.isReachable)
//    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]){
        
        self.updateData(applicationContext as [String : AnyObject])
    }
    
    
}



//MARK: HKWorkoutSessionDelegate

extension WAInterfaceController : HKWorkoutSessionDelegate{
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        
        // NSLog("WKSession state %@ -> %@", fromState.rawValue, toState.rawValue )
        
        switch toState {
        case .running:
            workoutDidStart(date)
        case .ended:
            workoutDidEnd(date)
        default:
            print("Unexpected state \(toState)")
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        // Do nothing for now
        let err = error as NSError
        NSLog("Error en workoutSession %@ - %@", workoutSession, err)
    }
    
    
    //MARK: HKWorkoutSessionDelegate Auxiliary Functions
    
    
    func workoutDidStart(_ date : Date) {
        
        self.sessionOnLabel.setHidden(false)
        
        if let healthStore = (WKExtension.shared().delegate as? ExtensionDelegate)?.healthStore {
            if let q = createHeartRateStreamingQuery(date) {
                self.query = q
                healthStore.execute(q)
            } else {
                self.startButton.setTitle("?")
            }
        }
    }
    
    func workoutDidEnd(_ date : Date) {
        
        self.sessionOnLabel.setHidden(true)
        
        if let healthStore = (WKExtension.shared().delegate as? ExtensionDelegate)?.healthStore {
            if let q = self.query {
                healthStore.stop(q)
                self.startButton.setTitle("")
            } else {
                self.startButton.setTitle("??")
            }
        }
    }
    
    
    
    func createHeartRateStreamingQuery(_ workoutStartDate: Date) -> HKQuery? {
        // adding predicate will not work
        // let predicate = HKQuery.predicateForSamplesWithStartDate(workoutStartDate, endDate: nil, options: HKQueryOptions.None)
        
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else { return nil }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: HKQueryOptions())
        
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
    
    
    func updateHeartRate(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        
        DispatchQueue.main.async {
            guard let sample = heartRateSamples.first else{return}
            let value = sample.quantity.doubleValue(for: self.heartRateUnit)
            //self.label.setText(String(UInt16(value)))
            
            //self.startButton.setTitle(String(UInt16(value)))
            
            self.hrLabel.setText(String(UInt16(value)))
            
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

extension WAInterfaceController : WAInterfaceNavigation
{
    
    func updateFields(){
        
        DispatchQueue.main.async(execute: { () -> Void in
            
            
            if let time = self.startTime {
                self.workoutTimer.setDate(time)
                if self.state == .recording{
                    self.workoutTimer.start()
                }
                else{
                    self.workoutTimer.stop()
                }
            }
            
            if let time = self.wStartTime {
                self.lapTimer.setDate(time)
                if self.state == .recording{
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
            
            if let v = self.ascent {
                
                let units = "m"
                self.climbingLabel.setText(String(format: "%5.0f%@", v, units))
                
            }
            
            if let wv = self.wDistancia, let xv = self.distancia {
                
                let v = xv - wv
                if v < 1000.0 {
                    
                    let units = "m"
                    self.distLapLabel.setText(String(format: "%3.0f%@", v, units))
                }
                else{
                    let units = "Km"
                    self.distLapLabel.setText(String(format: "%5.2f%@", v/1000.0, units))
                }
                
            }
            
            
            
            if self.hr != 0 && self.localMode == .remoteHR && self.state == .recording {
                self.hrLabel.setText(String(self.hr))
            }
            
            
            //  var stateIcon = "record_64"
            if self.stateChanged{
                switch self.state{
                    
                case .stopped:
                    //stateIcon = "record_64"
                    // self.startButton.setBackgroundImageNamed(stateIcon)
                    self.hrLabel.setText("START")
                    self.unitsLabel.setText("")
                case .paused:
                    //stateIcon = "pause_64"
                    //self.startButton.setBackgroundImageNamed(stateIcon)
                    self.hrLabel.setText("Paused")
                    self.unitsLabel .setText("")
                case .recording:
                    //stateIcon = "record_wp_64"
                    //self.startButton.setBackgroundImage(nil)
                    self.unitsLabel.setText("bps")
                    
                }
                self.stateChanged = false
                
            }
        })
    }
}


