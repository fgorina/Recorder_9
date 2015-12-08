//
//  DataController.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 25/9/15.
//  Copyright © 2015 Paco Gorina. All rights reserved.
//

import UIKit
import CoreMotion
import MapKit
import WatchConnectivity
import HealthKit

class DataController: NSObject {
    
    // MARK: Constants
    
    static  internal let kAppStateUpdated = "kAppStateUpdated"
    static  internal let kHRUpdated = "kHRUpdated"
    static  internal let kDataUpdated = "kDataUpdated"
    static  internal let kActivityUpdated = "kDataUpdated"
    
    let heartRateUnit = HKUnit(fromString: "count/min")
    
    // MARK: Data Sources
    
    var hrMonitor : TMKHeartRateMonitor
    var almeter : TMKAltimeterManager
    
    // MARK: State Variables
    
    var temps : NSTimeInterval = 0.0
    var distancia : Double = 0.0
    var distanciaPedometer : Double = 0.0
    var ascent : Double = 0.0
    var descent : Double = 0.0
    var altura : Double = 0.0
    var speed : Double = 0.0
    var vdop : Double = 0.0
    var HR : Int = 0
    var startTime : NSDate?
    var activity : CMMotionActivity?
    
    var wStartTime : NSDate?
    var wDistancia : Double = 0.0
    var wAscent : Double = 0.0
    var wDescent : Double = 0.0
    
    
    //MARK: Recording
    
    var doRecord : appState = .Stopped
    var recordingTrack : TGLTrack?
    var heartArray : [HKQuantitySample]?
    
    var deferringUpdates : Bool = false
    
    
    // MARK: Auxiliary
    
    
    var sendToWatch = false
    var wcsession : AnyObject?
    
    
    override init(){
        debugLaunch("DataController init enter")

        
        self.hrMonitor = TMKHeartRateMonitor()
        self.almeter = TMKAltimeterManager()
        super.init()
        
        if #available(iOS 9,*){
            if WCSession.isSupported(){
                
                let session = WCSession.defaultSession()
                session.delegate = self
                session.activateSession()
                self.wcsession = session
                
                if session.paired && session.watchAppInstalled{
                    self.sendToWatch = true
                }
            }
        }
        
        self.almeter.delegate = self
        self.almeter.hrMonitor = self.hrMonitor // Probablement ho haurem de canviar per que el hrMonitor tambe el tingui el almeter
        
        self.initNotifications()
        debugLaunch("DataController init exit")

        
    }
    
    func getAppState() -> [String : AnyObject]{
        
        var dict : Dictionary<String, AnyObject> = [String : AnyObject]()
        
        dict["state"] = self.doRecord.rawValue
        
        dict["temps"] = temps
        dict["distancia"]  = distancia
        dict["distanciaPedometer"]  =  distanciaPedometer
        dict["ascent"]  =  ascent
        dict["descent"]  =  descent
        dict["altura"]  =  altura
        dict["speed"] = speed
        dict["vdop"]  =  vdop
        dict["HR"]  =  HR
        dict["startTime"]  =  startTime
        dict["activity"]  =  activity?.activEnum().rawValue
        dict["ascentSpeed"] = self.almeter.ascentSpeed
        dict["descentSpeed"] = self.almeter.descentSpeed
        
        dict["wStartTime"]  =  wStartTime
        dict["wDistancia"]  =  wDistancia
        dict["wAscent"]  =  wAscent
        dict["wDescent"]  =  wDescent
        dict["hasHrMonitor"] = self.hrMonitor.connected
        
        return dict
        
    }
    
    func initNotifications()
    {
           // NSNotificationCenter.defaultCenter().addObserver(self, selector: "conexionActive:", name: TMKHeartRateMonitor.kSubscribedToHRStartedNotification, object: nil)
           // NSNotificationCenter.defaultCenter().addObserver(self, selector: "conexionClosed:", name: TMKHeartRateMonitor.kSubscribedToHRStopedNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "hrReceived:", name: TMKHeartRateMonitor.kHRReceivedNotification, object: nil)
        
        
    }
    
    func hrReceived(not : NSNotification)
    {
        if let sample = not.object as? HKQuantitySample {
            
            if self.heartArray == nil{
                self.heartArray = [HKQuantitySample]()
            }
            
            self.heartArray!.append(sample)
            
            let value = Int(floor(sample.quantity.doubleValueForUnit(heartRateUnit)))
            if value != self.HR {
                self.HR = value
                self.sendHRUpdatedNotification()
                if #available(iOS 9,*){
                    if self.sendToWatch{
                        self.sendStateToWatch()
                    }
                }

            }
        }
    }
    
    
    // MARK: Send Notifications
    
    func sendDataUpdatedNotification(){
        
        let notification = NSNotification(name:DataController.kDataUpdated, object:self)
        NSNotificationCenter.defaultCenter().postNotification(notification)
        
        
        if #available(iOS 9,*){
            if self.sendToWatch{
                self.sendStateToWatch()
            }
         }
        if GlobalConstants.debug{
            NSLog("Sending %@", notification)
        }
        
        
    }
    
    func sendActivityUpdatedNotification(){
        
        if let actv = self.activity {
            let dict = ["activity" : actv]
            
            let notification = NSNotification(name:DataController.kActivityUpdated, object:self, userInfo: dict)
            NSNotificationCenter.defaultCenter().postNotification(notification)
            
            if GlobalConstants.debug{
                NSLog("Sending %@", notification)
            }
        }
    }
    
    func sendHRUpdatedNotification(){
        
        let dict = ["hr" : self.HR]
        
        let notification = NSNotification(name:DataController.kHRUpdated, object:self.HR, userInfo: dict)
        NSNotificationCenter.defaultCenter().postNotification(notification)
        
        if GlobalConstants.debug{
            NSLog("Sending %@", notification)
        }
        
    }
    
    
    func sendStateUpdatedNotification(){
        
        let dict = ["state" : self.doRecord.rawValue]
        
        let notification = NSNotification(name:DataController.kAppStateUpdated, object:self, userInfo: dict)
        NSNotificationCenter.defaultCenter().postNotification(notification)
        
        if #available(iOS 9,*){
            if self.sendToWatch{
                self.sendStateToWatch()
            }
        }
        
        if GlobalConstants.debug{
            NSLog("Sending %@", notification)
        }
    }
    
    
  @available(iOS 9, *)
    func sendStateToWatch(){
        if self.sendToWatch{
            
            let info = self.getAppState()
            
            if let session = wcsession as! WCSession?{
                
                debugLaunch("Sending data to Watch")
                
                do {
                    try session.updateApplicationContext(info)
                }
                catch _{
                    NSLog("Error sending data to watch")
                }
            }
        }
    }
    
    
    
    // MARK: Actions
    
    func doAddWaypoint(){
        if let track = self.recordingTrack {    // Get recording track
            
                if let tp = track.data.last {
                    self.setWpData()
                    let wp = TMKWaypoint.newWaypointFromTrackPoint(_trackPoint: tp)
                    track.addWaypoint(wp)
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in

                    let del : AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                    let tpJSON = wp.toJSON()
                    tpJSON.setValue(2, forKey: "start");
                    
                    del.pushPoint(tpJSON)
                    del.procesServerQueue(false)    // Force a processQueue to send the WP if connected
                    })
                    self.sendStateUpdatedNotification()
                }
        }
    }
    
    func pauseRecording(){
        
        if self.doRecord == .Recording {
            self.almeter.pauseUpdating()
            self.doRecord = .Paused
        
            self.sendStateUpdatedNotification()
        }
        
    }
    
    func resumeRecording(){
        if self.doRecord == .Paused {
            self.almeter.resumeUpdating()
            self.doRecord = .Recording
            
        self.sendStateUpdatedNotification()
        }
    }
    
    
    func stopRecording(){
        
        if self.doRecord != .Stopped {
        
            self.hrMonitor.stopScanning()
            self.almeter.stopUpdating()
            self.doRecord = .Stopped
            let tp = self.recordingTrack?.data.last
            
            self.recordingTrack?.closeRecording(self.heartArray)
            self.recordingTrack = nil
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                
                // Resend last point with a 3 in start to stop server status
                if let tpx = tp {
                    let del : AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                    let tpJSON = tpx.toJSON()
                    tpJSON.setValue(3, forKey: "start")     // Code for end of track
                    del.pushPoint(tpJSON)
                    del.procesServerQueue(false)    // Force a processQueue to send the WP if connected
                    
                }
            })
            self.sendStateUpdatedNotification()
        }
    }
    
    func startRecording(){
        
        if self.doRecord == .Stopped{
        
            self.recordingTrack = TGLTrack()
            self.resetViewData()
            
            // Init heart array 
            
            if let _ = self.heartArray{
                self.heartArray!.removeAll()
            }
            else{
                self.heartArray = [HKQuantitySample]()
            }
            if let track = self.recordingTrack{
                track.openRecording()
                self.hrMonitor.startScanning()
                self.almeter.startUpdating()
                self.doRecord = .Recording
                self.sendStateUpdatedNotification()
                
            }
            else
            {
                NSLog("No puc obrir la track")
            }
        }
    }
    
    
    func resetViewData()
    {
        self.distancia = 0.0
        self.altura = 0.0
        self.ascent = 0.0
        self.descent = 0.0
        self.vdop = 0.0
        self.startTime = NSDate()
        self.setWpData()
        
    }
    
    func setWpData()
    {
        self.wStartTime = NSDate()
        self.wDistancia = self.distancia
        self.wAscent = self.ascent
        self.wDescent = self.descent
    }
    
}

// MARK: TMKAltimeterManagerDelegate

extension DataController : TMKAltimeterManagerDelegate {
    
    func updateActivity(activity : CMMotionActivity){
        
        self.activity = activity
        self.sendActivityUpdatedNotification()
        
        
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        
        if GlobalConstants.debug {
            if let myLoc = locations.last {
                NSLog("Posicio amb alçada %f +/- %f", myLoc.altitude, myLoc.verticalAccuracy)
            }
        }
        
        if self.doRecord == .Recording {
            let locs  = locations
            
            if let track = self.recordingTrack {    // Send data to the track
                track.addLocations(locs, hr:self.HR, force:false, activity:self.almeter.actualActivity)
                
                if let lpt = track.data.last as TGLTrackPoint? {
                    
                    self.temps = lpt.tempsOrigen
                    self.distancia = lpt.distanciaOrigen
                    self.altura = lpt.ele
                    //self.tempsStr = lpt.tempsOrigenAsString
                    
                    self.ascent = track.totalAscent
                    self.descent = track.totalDescent
                    self.vdop = lpt.vPrecision
                    
                    if UIApplication.sharedApplication().applicationState == UIApplicationState.Active{
                        
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.sendDataUpdatedNotification()
                        })
                    } else{
                        if #available(iOS 9,*){
                            if self.sendToWatch{
                                self.sendStateToWatch()
                            }
                        }
                    }
                }
            }
        }
        
        if !self.deferringUpdates {
            let distance : CLLocationDistance =  1000.0 // Update every km
            let time : NSTimeInterval = 600.0 // Or every 10'
            
            manager.allowDeferredLocationUpdatesUntilTraveled(distance,  timeout:time)
            self.deferringUpdates = true
            
        }
    }
    
    func updateTrackPoints(dat : [TGLTrackPoint])
    {
        if self.doRecord == .Recording {
            if let track = self.recordingTrack {
                track.addPoints(dat)
                if let lpt = track.data.last as TGLTrackPoint? {
                    
                    self.temps = lpt.tempsOrigen
                    self.distancia = lpt.distanciaOrigen
                    self.distanciaPedometer = lpt.distanciaPedometer
                    self.altura = lpt.ele
                    //self.tempsStr = lpt.tempsOrigenAsString
                    
                    self.ascent = track.totalAscent
                    self.descent = track.totalDescent
                    self.vdop = lpt.vPrecision
                    
                    NSLog("Dades processades %l", dat.count)
                    
                    if UIApplication.sharedApplication().applicationState == UIApplicationState.Active{
                        self.sendDataUpdatedNotification()
                    }
                    else{
                        if #available(iOS 9,*){
                            if self.sendToWatch{
                                self.sendStateToWatch()
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        if GlobalConstants.debug {
            NSLog("User Auth Request answered")
        }
        
    }
    
    
    func locationManager(manager: CLLocationManager, didFinishDeferredUpdatesWithError error: NSError?){
        self.deferringUpdates = false
    }
    
    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        
    }
    
    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        
    }
    
    
    func locationManager(manager: CLLocationManager, monitoringDidFailForRegion region: CLRegion?, withError error: NSError) {
        NSLog("Error a la regio %@", error);
    }
    
    
    func updateSpeed(speed: CLLocationSpeed) {
        self.speed = speed
    }
    
}


@available(iOS 9.0, *)
extension DataController :  WCSessionDelegate{
    
    func sessionWatchStateDidChange(session: WCSession) {
        
        if session.paired && session.watchAppInstalled{
            self.sendToWatch = true
        }
        else{
            self.sendToWatch = false
        }
        
    }
    
    func session(session: WCSession, didReceiveMessageData messageData: NSData) {

        if let dades = NSKeyedUnarchiver.unarchiveObjectWithData(messageData) as? [HKQuantitySample]{
            
            // Check if we already have a heart monitor. Forget local data
            
            if self.hrMonitor.connected{
                return
            }
            
            if self.heartArray != nil{
                self.heartArray!.appendContentsOf(dades)
            }
            if let lastSample = dades.last {
                let  v = lastSample.quantity.doubleValueForUnit(self.heartRateUnit)
                self.HR = Int(v)
                self.sendHRUpdatedNotification()
            }
        }
    }
    
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject]) {
        if let op = message["op"] as? String{
            
            switch op {
                
                case "start":
                
                if self.doRecord == .Stopped {
                        
                        self.startRecording()
                }
                
                
            case "stop" :
                if self.doRecord == .Recording || self.doRecord == .Paused {
                    
                    self.stopRecording()
                }
                
            case "waypoint" :
                if self.doRecord == .Recording || self.doRecord == .Paused {
                    
                    self.doAddWaypoint()
                }
               
            default:
                NSLog("Op de Watch desconeguda", op)
            }
            
        }
    }

}


