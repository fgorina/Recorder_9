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
    
    let heartRateUnit = HKUnit(from: "count/min")
    
    // MARK: Data Sources
    
    var hrMonitor : TMKHeartRateMonitor
    var almeter : TMKAltimeterManager
    
    // MARK: State Variables
    
    var temps : TimeInterval = 0.0
    var distancia : Double = 0.0
    var distanciaPedometer : Double = 0.0
    var ascent : Double = 0.0
    var descent : Double = 0.0
    var altura : Double = 0.0
    var speed : Double = 0.0
    var vdop : Double = 0.0
    var HR : Int = 0
    var startTime : Date?
    var activity : CMMotionActivity?
    
    var wStartTime : Date?
    var wDistancia : Double = 0.0
    var wAscent : Double = 0.0
    var wDescent : Double = 0.0
    
    var slope : Double = 0.0    // Slope of last knp points. Aprox 5 = 50m
    var VAM : Double = 0.0    // Slope of last knp points. Aprox 5 = 50m
    let knp = 2
    
    
    //MARK: Recording
    
    var doRecord : appState = .stopped
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
                
                let session = WCSession.default()
                session.delegate = self
                session.activate()
                self.wcsession = session
                
                if session.isPaired && session.isWatchAppInstalled{
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
        
        dict["state"] = self.doRecord.rawValue as AnyObject?
        
        dict["temps"] = temps as AnyObject?
        dict["distancia"]  = distancia as AnyObject?
        dict["distanciaPedometer"]  =  distanciaPedometer as AnyObject?
        dict["ascent"]  =  ascent as AnyObject?
        dict["descent"]  =  descent as AnyObject?
        dict["altura"]  =  altura as AnyObject?
        dict["speed"] = speed as AnyObject?
        dict["vdop"]  =  vdop as AnyObject?
        dict["HR"]  =  HR as AnyObject?
        dict["startTime"]  =  startTime as AnyObject?
        dict["activity"]  =  activity?.activEnum().rawValue as AnyObject?
        dict["ascentSpeed"] = self.almeter.ascentSpeed as AnyObject?
        dict["descentSpeed"] = self.almeter.descentSpeed as AnyObject?
        
        dict["wStartTime"]  =  wStartTime as AnyObject?
        dict["wDistancia"]  =  wDistancia as AnyObject?
        dict["wAscent"]  =  wAscent as AnyObject?
        dict["wDescent"]  =  wDescent as AnyObject?
        dict["hasHrMonitor"] = self.hrMonitor.connected as AnyObject?
        
        return dict
        
    }
    
    func initNotifications()
    {
           // NSNotificationCenter.defaultCenter().addObserver(self, selector: "conexionActive:", name: TMKHeartRateMonitor.kSubscribedToHRStartedNotification, object: nil)
           // NSNotificationCenter.defaultCenter().addObserver(self, selector: "conexionClosed:", name: TMKHeartRateMonitor.kSubscribedToHRStopedNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(DataController.hrReceived(_:)), name: NSNotification.Name(rawValue: TMKHeartRateMonitor.kHRReceivedNotification), object: nil)
        
        
    }
    
    func hrReceived(_ not : Notification)
    {
        if let sample = not.object as? HKQuantitySample {
            
            if self.heartArray == nil{
                self.heartArray = [HKQuantitySample]()
            }
            
            self.heartArray!.append(sample)
            
            let value = Int(floor(sample.quantity.doubleValue(for: heartRateUnit)))
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
        
        let notification = Notification(name:Notification.Name(rawValue: DataController.kDataUpdated), object:self)
        NotificationCenter.default.post(notification)
        
        
        if #available(iOS 9,*){
            if self.sendToWatch{
                self.sendStateToWatch()
            }
         }
        if GlobalConstants.debug{
            NSLog("Sending %@", notification.description)
        }
        
        
    }
    
    func sendActivityUpdatedNotification(){
        
        if let actv = self.activity {
            let dict = ["activity" : actv]
            
            let notification = Notification(name:Notification.Name(rawValue: DataController.kActivityUpdated), object:self, userInfo: dict)
            NotificationCenter.default.post(notification)
            
            if GlobalConstants.debug{
                NSLog("Sending %@", notification.description)
            }
        }
    }
    
    func sendHRUpdatedNotification(){
        
        let dict = ["hr" : self.HR]
        
        let notification = Notification(name:Notification.Name(rawValue: DataController.kHRUpdated), object:self.HR, userInfo: dict)
        NotificationCenter.default.post(notification)
        
        if GlobalConstants.debug{
            NSLog("Sending %@", notification.description)
        }
        
    }
    
    
    func sendStateUpdatedNotification(){
        
        let dict = ["state" : self.doRecord.rawValue]
        
        let notification = Notification(name:Notification.Name(rawValue: DataController.kAppStateUpdated), object:self, userInfo: dict)
        NotificationCenter.default.post(notification)
        
        if #available(iOS 9,*){
            if self.sendToWatch{
                self.sendStateToWatch()
            }
        }
        
        if GlobalConstants.debug{
            NSLog("Sending %@", notification.description)
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
                    DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: { () -> Void in

                    let del : AppDelegate = UIApplication.shared.delegate as! AppDelegate
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
        
        if self.doRecord == .recording {
            //self.almeter.pauseUpdating()
            self.doRecord = .paused
        
            self.sendStateUpdatedNotification()
        }
        
    }
    
    func resumeRecording(){
        if self.doRecord == .paused {
            //self.almeter.resumeUpdating()
            self.doRecord = .recording
            
        self.sendStateUpdatedNotification()
        }
    }
    
    
    func stopRecording(){
        
        if self.doRecord != .stopped {
        
            self.hrMonitor.stopScanning()
            self.almeter.stopUpdating()
            self.doRecord = .stopped
            let tp = self.recordingTrack?.data.last
            
            self.recordingTrack?.closeRecording(self.heartArray)
            self.recordingTrack = nil
            
            DispatchQueue.main.async(execute: { () -> Void in
                
                // Resend last point with a 3 in start to stop server status
                if let tpx = tp {
                    let del : AppDelegate = UIApplication.shared.delegate as! AppDelegate
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
        
        if self.doRecord == .stopped{
        
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
                self.doRecord = .recording
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
        self.startTime = Date()
        self.setWpData()
        
    }
    
    func setWpData()
    {
        self.wStartTime = Date()
        self.wDistancia = self.distancia
        self.wAscent = self.ascent
        self.wDescent = self.descent
    }
    
}

// MARK: TMKAltimeterManagerDelegate

extension DataController : TMKAltimeterManagerDelegate {
    
    func updateActivity(_ activity : CMMotionActivity){
        
        self.activity = activity
        self.sendActivityUpdatedNotification()
        
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        
        if GlobalConstants.debug {
            if let myLoc = locations.last {
                NSLog("Posicio amb alçada %f +/- %f", myLoc.altitude, myLoc.verticalAccuracy)
            }
        }
        
        if self.doRecord == .recording || self.doRecord == .paused{
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
                    self.slope  = track.getSlope(knp)
                    self.VAM  = track.getVAM(knp)
                    
                    if UIApplication.shared.applicationState == UIApplicationState.active{
                        
                        DispatchQueue.main.async(execute: { () -> Void in
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
            let time : TimeInterval = 600.0 // Or every 10'
            
            manager.allowDeferredLocationUpdates(untilTraveled: distance,  timeout:time)
            self.deferringUpdates = true
            
        }
    }
    
    func updateTrackPoints(_ dat : [TGLTrackPoint])
    {
        if self.doRecord == .recording  || self.doRecord == .paused{
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
                    
                    self.slope  = track.getSlope(knp)
                    self.VAM  = track.getVAM(knp)
                   
                    NSLog("Dades processades %l", dat.count)
                    
                    if UIApplication.shared.applicationState == UIApplicationState.active{
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
    
        
    func locationManager(_ manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        if GlobalConstants.debug {
            NSLog("User Auth Request answered")
        }
        
    }
    
    
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: NSError?){
        self.deferringUpdates = false
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        
    }
    
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailForRegion region: CLRegion?, withError error: NSError) {
        NSLog("Error a la regio %@", error);
    }
    
    
    func updateSpeed(_ speed: CLLocationSpeed) {
        self.speed = speed
    }
    
}


@available(iOS 9.0, *)
extension DataController :  WCSessionDelegate{
    /** Called when all delegate callbacks for the previously selected watch has occurred. The session can be re-activated for the now selected watch using activateSession. */
    @available(iOS 9.3, *)
    public func sessionDidDeactivate(_ session: WCSession) {
    
    }

    /** Called when the session can no longer be used to modify or add any new transfers and, all interactive messages will be cancelled, but delegate callbacks for background transfers can still occur. This will happen when the selected watch is being changed. */
    @available(iOS 9.3, *)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        
        
    }

    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    @available(iOS 9.3, *)
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        
    }

    
    func sessionWatchStateDidChange(_ session: WCSession) {
        
        if session.isPaired && session.isWatchAppInstalled{
            self.sendToWatch = true
        }
        else{
            self.sendToWatch = false
        }
        
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {

        if let dades = NSKeyedUnarchiver.unarchiveObject(with: messageData) as? [HKQuantitySample]{
            
            // Check if we already have a heart monitor. Forget local data
            
            if self.hrMonitor.connected{
                return
            }
            
            if self.heartArray != nil{
                self.heartArray!.append(contentsOf: dades)
            }
            if let lastSample = dades.last {
                let  v = lastSample.quantity.doubleValue(for: self.heartRateUnit)
                self.HR = Int(v)
                self.sendHRUpdatedNotification()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let op = message["op"] as? String{
            
            switch op {
                
                case "start":
                
                if self.doRecord == .stopped {
                        
                        self.startRecording()
                }
                
                
            case "stop" :
                if self.doRecord == .recording || self.doRecord == .paused {
                    
                    self.stopRecording()
                }
                
            case "waypoint" :
                if self.doRecord == .recording || self.doRecord == .paused {
                    
                    self.doAddWaypoint()
                }
               
            default:
                NSLog("Op de Watch desconeguda", op)
            }
            
        }
    }

}


