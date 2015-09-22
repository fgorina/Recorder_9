//
//  ViewController.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 30/1/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit
import MapKit
import CoreMotion

enum appState : Int {
    case Stopped = 0
    case Recording
    case Paused
}



class ViewController: UIViewController, CLLocationManagerDelegate {
    
    var debug = true
    
    @IBOutlet weak var lTemps: UILabel!
    @IBOutlet weak var lDistancia: UILabel!
    @IBOutlet weak var lPedometerDistance: UILabel!
    @IBOutlet weak var lAscent: UILabel!
    @IBOutlet weak var lAltura: UILabel!
    @IBOutlet weak var lErrorAltura: UILabel!
    @IBOutlet weak var lDescent: UILabel!
    @IBOutlet weak var lHR: UILabel!
    @IBOutlet weak var bStartStop: UIButton!
    @IBOutlet weak var wpButton: UIButton!
    @IBOutlet weak var lwActivityButton: UIButton!
    
    @IBOutlet weak var lwTemps: UILabel!
    @IBOutlet weak var lwDistancia: UILabel!
    @IBOutlet weak var lwAscent: UILabel!
    @IBOutlet weak var lwDescent: UILabel!
    @IBOutlet weak var lwActivity: UILabel!
    
    
    
    
    var temps : NSTimeInterval = 0.0
    var tempsStr : String = "00:00:00"
    var distancia : Double = 0.0
    var distanciaPedometer : Double = 0.0
    var ascent : Double = 0.0
    var descent : Double = 0.0
    var altura : Double = 0.0
    var vdop : Double = 0.0
    var HR : Int = 0
    var startTime : NSDate?
    var activity : String = "Unknown"
    
    // Temps des de l'ultim lap/waypoint
    
    var wStartTime : NSDate?
    var wDistancia : Double = 0.0
    var wAscent : Double = 0.0
    var wDescent : Double = 0.0
    
    var lastPoint : TGLTrackPoint?
    
    var hrMonitor : TMKHeartRateMonitor
    var almeter : TMKAltimeterManager
    weak var timer : NSTimer?
    
    //MARK : Recording
    
    var heartOn : Bool = false
    var doRecord : appState = .Stopped
    var recordingTrack : TGLTrack?
    
    var deferringUpdates : Bool = false
    
    
    // MARK: - Init
    //
    //    internal init(){
    //
    //        self.hrMonitor = TMKHeartRateMonitor()
    //        self.almeter = TMKAltimeterManager()
    //        //super.init()
    //        self.almeter.delegate = self
    //        self.initNotifications()
    //
    //    }
    
    required init?(coder aDecoder: NSCoder) {
        
        self.hrMonitor = TMKHeartRateMonitor()
        self.almeter = TMKAltimeterManager()
        super.init(coder: aDecoder)
        self.almeter.delegate = self
        self.almeter.hrMonitor = self.hrMonitor // Probablement ho haurem de canviar per aue el hrMonitor tambe el tingui el almeter
        
        let del = UIApplication.sharedApplication().delegate as! AppDelegate
        
        del.rootController = self
        
        self.initNotifications()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        if(CMMotionActivityManager.isActivityAvailable()){
            if let act = self.lwActivityButton {
                act.hidden = false
            }
        }
        
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: Notifications
    
    func initNotifications()
    {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "conexionActive:", name: self.hrMonitor.kSubscribedToHRStartedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "conexionClosed:", name: self.hrMonitor.kSubscribedToHRStopedNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "hrReceived:", name: self.hrMonitor.kHRReceivedNotification, object: nil)
        
        
    }
    
    func conexionActive(not : NSNotification){
        
        NSLog("Notification %@", not)
        
        let img : UIImage? = UIImage(named: "record_heart_on_64.png")
        self.bStartStop.setImage(img, forState: UIControlState.Normal)
        self.heartOn = true
    }
    
    func conexionClosed(not : NSNotification){
        NSLog("Notification %@", not)
        self.heartOn = false
        var imageName = "record_64"
        if self.doRecord == .Recording{
            imageName = "record_on_64"
        }
        self.bStartStop.setImage(UIImage(named: imageName), forState: UIControlState.Normal)
        
    }
    
    func hrReceived(not : NSNotification)
    {
        let value = not.object as! Int
        self.HR = value
        if UIApplication.sharedApplication().applicationState == UIApplicationState.Active{
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                let txt = NSString(format: "%d bpm", value)
                self.lHR.text = txt as String;
                if self.heartOn {
                    self.bStartStop.setImage(UIImage(named: "record_heart_64.png"), forState: UIControlState.Normal)
                    self.heartOn = !self.heartOn
                }
                else
                {
                    self.bStartStop.setImage(UIImage(named: "record_heart_on_64.png"), forState: UIControlState.Normal)
                    self.heartOn = !self.heartOn
                }
            })
        }
        
        //NSLog("Notification %@", not)
    }
    
    //MARK: - Actions
    
    
    
    @IBAction func  startStop(src:AnyObject)
    {
        if self.doRecord == .Stopped
        {
            self.startRecording()
        }
        else if self.doRecord == .Recording
        {
            self.pauseRecording()
        }
        else if self.doRecord == .Paused
        {
            self.resumeRecording()
        }
    }
    
    
    @IBAction func  addWaypoint(src:AnyObject)
    {
        
        if self.doRecord == .Paused {
            self.stopRecording()
        }
        else
        {
            self.doAddWaypoint()    
         }
    }
    
    func doAddWaypoint(){
        if let track = self.recordingTrack {    // Get recording track
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                if let tp = track.data.last {
                    self.setWpData()
                    let wp = TMKWaypoint.newWaypointFromTrackPoint(_trackPoint: tp)
                    track.addWaypoint(wp)
                    let del : AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                    let tpJSON = wp.toJSON()
                    tpJSON.setValue(2, forKey: "start");
                    
                    del.pushPoint(tpJSON)
                    del.procesServerQueue(false)    // Force a processQueue to send the WP if connected
                    
                }
            })
        }
    }
    
    func pauseRecording(){
        self.almeter.pauseUpdating()
        self.bStartStop.setImage(UIImage(named: "pause_64"), forState: UIControlState.Normal)
        self.wpButton.setImage(UIImage(named: "record_64"), forState: .Normal)
        self.wpButton.setImage(UIImage(named: "record_on_64"), forState: .Highlighted)
        self.doRecord = .Paused
        
        
        
    }
    
    func resumeRecording(){
        self.almeter.resumeUpdating()
        if self.hrMonitor.connected {
            
            self.bStartStop.setImage(UIImage(named: "record_heart_on_64.png"), forState:UIControlState.Normal)
        }
        else
        {
            self.bStartStop.setImage(UIImage(named: "record_on_64"), forState:UIControlState.Normal)
        }
        self.wpButton.setImage(UIImage(named: "record_wp_64"), forState: .Normal)
        self.wpButton.setImage(UIImage(named: "record_wp_on_64"), forState: .Highlighted)
        self.doRecord = .Recording
        
    }
    
    func stopRecording(){
        
        self.hrMonitor.stopScanning()
        self.almeter.stopUpdating()
        self.doRecord = .Stopped
        let tp = self.recordingTrack?.data.last
        
        self.recordingTrack?.closeRecording()
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
            
            if let tim = self.timer{
                tim.invalidate()
                self.timer = nil
            }
            self.bStartStop.setImage(UIImage(named: "record_64"), forState: UIControlState.Normal)
            
            self.wpButton.setImage(UIImage(named: "record_wp_64"), forState: .Normal)
            self.wpButton.setImage(UIImage(named: "record_wp_on_64"), forState: .Highlighted)
            
            self.wpButton.hidden = true
        })
    }
    
    func startRecording(){
        
        if self.doRecord == .Recording{
            return
        }
        
        self.recordingTrack = TGLTrack()
        self.resetViewData()
        
        if let track = self.recordingTrack{
            track.openRecording()
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                
                self.bStartStop.setImage(UIImage(named: "record_on_64"), forState: UIControlState.Normal)
                
                self.wpButton.setImage(UIImage(named: "record_wp_64"), forState: .Normal)
                self.wpButton.setImage(UIImage(named: "record_wp_on_64"), forState: .Highlighted)
                
                self.wpButton.hidden = false
                
                if self.timer == nil {
                    
                    let aTimer = NSTimer(timeInterval: 1.0, target: self, selector: "updateTime:", userInfo: nil, repeats: true)
                    let runLoop = NSRunLoop.currentRunLoop()
                    runLoop.addTimer(aTimer, forMode:NSDefaultRunLoopMode)
                    self.timer = aTimer
                    
                }
            })
            self.hrMonitor.startScanning()
            self.almeter.startUpdating()
            
            self.doRecord = .Recording
        }
        else
        {
            NSLog("No puc obrir la track")
        }
        
    }
    
    func updateTime(timer : NSTimer)
    {
        if let tim = self.startTime, wtim = self.wStartTime {
            let temps = NSDate().timeIntervalSinceDate(tim)
            let wtemps = NSDate().timeIntervalSinceDate(wtim)
            
            self.tempsStr = TGLTrackPoint.stringFromTimeInterval(temps)
            let wTempsStr = TGLTrackPoint.stringFromTimeInterval(wtemps)
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.lTemps.text = self.tempsStr
                self.lwTemps.text = wTempsStr
            })
        }
    }
    
    func updateActivity()
    {
        if UIApplication.sharedApplication().applicationState == UIApplicationState.Active{
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                
                if self.lwActivity != nil{
                    self.lwActivity.text = self.activity
                    let imgName = "act_" + self.activity + "_64"
                    if let img = UIImage(named: imgName)
                    {
                        self.lwActivityButton.setImage(img, forState: UIControlState.Normal)
                    }
                }
            })
        }
        
    }
    
    func updateViewData()
    {
        
        //self.lTemps.text = self.tempsStr
        self.lDistancia.text = NSString(format: "%7.2f", self.distancia) as String
        self.lPedometerDistance.text = NSString(format: "%7.2f", self.distanciaPedometer) as String
        self.lAltura.text = NSString(format: "%5.0f +/- %5.2f", self.altura, self.vdop) as String
        self.lAscent.text = NSString(format: "%5.0f", self.ascent) as String
        self.lDescent.text = NSString(format: "%5.0f", self.descent) as String
        
        self.lwDistancia.text = NSString(format: "%7.2f", self.distancia-self.wDistancia) as String
        self.lwAscent.text = NSString(format: "%5.0f", self.ascent-self.wAscent) as String
        self.lwDescent.text = NSString(format: "%5.0f", self.descent - self.wDescent) as String
        
        
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
    
    @IBAction func openSettings()
    {
        
    }
    
    
    //MARK: - CLLocationManagerDelegate
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        if self.debug {
            NSLog("User Auth Request answered")
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
                        
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.updateViewData()
                        })
                    }
                }
                
            }
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if self.debug {
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
                                self.updateViewData()
                            })
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
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == "sSettingsSegue"
        {
            NSLog("Hello Segue")
        }
    }
    
    
}

