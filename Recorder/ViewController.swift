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



class ViewController: UIViewController, CLLocationManagerDelegate {
    
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
    
    
    var tempsStr : String = "00:00:00"
    
    var heartOn : Bool = false
    
    weak var timer : NSTimer?
    weak var data : DataController?
    
    
    
    
    
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
        
        debugLaunch("ViewController init coder enter")
        super.init(coder: aDecoder)
        
        commonInit()
        debugLaunch("ViewController init coder exit")
        
        
        
    }
    
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        debugLaunch("ViewController init nibname enter")
       
        commonInit()
        
        debugLaunch("ViewController init nibname exit")

    }
    
    func commonInit(){
        
        debugLaunch("ViewController commonInit entered")
        
        let del = UIApplication.sharedApplication().delegate as! AppDelegate
        del.dataController = DataController()
        self.data = del.dataController
        del.rootController = self
        self.initNotifications()
        
        debugLaunch("ViewController commonInit exited")
        
        
    }
    
    
    
    override func viewDidLoad() {
        debugLaunch("ViewController viewDidLoad enter")
        
        
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        if(CMMotionActivityManager.isActivityAvailable()){
            if let act = self.lwActivityButton {
                act.hidden = false
            }
        }
        
        // Update data to the one in the data controller
        
        if let dat = self.data {
            let state : appState = dat.doRecord
            
            switch state {
                
                
            case .Stopped :
                self.stopRecording()
                
            case .Recording :
                self.startRecording()
                
            case .Paused :
                self.pauseRecording()
                
            }
        }
        
        self.updateActivity()
        self.updateViewData(nil)
        
        debugLaunch("ViewController viewDidLoad exit")
        
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: Notifications
    
    func initNotifications()
    {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "conexionActive:", name: TMKHeartRateMonitor.kSubscribedToHRStartedNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "conexionClosed:", name: TMKHeartRateMonitor.kSubscribedToHRStopedNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "hrReceived:", name: DataController.kHRUpdated, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateState:", name: DataController.kAppStateUpdated, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateActivity", name: DataController.kActivityUpdated, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateViewData:", name: DataController.kDataUpdated, object: nil)
        
        
    }
    
    func conexionActive(not : NSNotification){
        
        NSLog("Notification %@", not)
        self.heartOn = true
        
        let img : UIImage? = UIImage(named: "record_heart_on_64.png")
        self.bStartStop.setImage(img, forState: UIControlState.Normal)
    }
    
    func conexionClosed(not : NSNotification){
        NSLog("Notification %@", not)
        var imageName = "record_64"
        
        if let record = self.data?.doRecord {
            if record == .Recording{
                imageName = "record_on_64"
                
            }
        }
        
        self.heartOn = false
        self.bStartStop.setImage(UIImage(named: imageName), forState: UIControlState.Normal)
        
    }
    
    func hrReceived(not : NSNotification)
    {
        if let value = not.object as? Int{
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
        }
        
        //NSLog("Notification %@", not)
    }
    
    //MARK: - Actions
    
    
    
    @IBAction func  startStop(src:AnyObject)
    {
        if let dat = self.data {
            
            if dat.doRecord == .Stopped
            {
                dat.startRecording()
            }
            else if dat.doRecord == .Recording
            {
                dat.pauseRecording()
            }
            else if dat.doRecord == .Paused
            {
                dat.resumeRecording()
            }
            
        }
    }
    
    
    @IBAction func  addWaypoint(src:AnyObject)
    {
        
        if let dat = self.data {
            
            if dat.doRecord == .Paused {
                dat.stopRecording()
            }
            else
            {
                dat.doAddWaypoint()
            }
        }
    }
    
    
    func updateState(notification: NSNotification)
    {
        
        if let dict = notification.userInfo {
            let state : appState = appState(rawValue: dict["state"] as! Int)!
            
            switch state {
                
                
            case .Stopped :
                self.stopRecording()
                
            case .Recording :
                self.startRecording()
                
            case .Paused :
                self.pauseRecording()
                
            }
        }
    }
    
    
    func pauseRecording(){
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.bStartStop.setImage(UIImage(named: "pause_64"), forState: UIControlState.Normal)
            self.wpButton.setImage(UIImage(named: "record_64"), forState: .Normal)
            self.wpButton.setImage(UIImage(named: "record_on_64"), forState: .Highlighted)
        })
        
        
    }
    
    func stopRecording(){
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
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
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            
            if let hrMonitor = self.data?.hrMonitor {
                if hrMonitor.connected {
                    
                    self.bStartStop.setImage(UIImage(named: "record_heart_on_64.png"), forState:UIControlState.Normal)
                }
                else
                {
                    self.bStartStop.setImage(UIImage(named: "record_on_64"), forState:UIControlState.Normal)
                }
            }
            else
            {
                self.bStartStop.setImage(UIImage(named: "record_on_64"), forState:UIControlState.Normal)
            }
            
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
        
    }
    
    func updateTime(timer : NSTimer)
    {
        if let dat = self.data{
            if let tim = dat.startTime, wtim = dat.wStartTime {
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
    }
    
    func updateActivity()
    {
        if UIApplication.sharedApplication().applicationState == UIApplicationState.Active{
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                
                if let act = self.data?.activity where self.lwActivity != nil {
                    self.lwActivity.text = act.stringDescription
                    let imgName = "act_" + act.stringDescription + "_64"
                    if let img = UIImage(named: imgName)
                    {
                        self.lwActivityButton.setImage(img, forState: UIControlState.Normal)
                    }
                }
            })
        }
    }
    
    func updateViewData(notification : NSNotification?)
    {
        
        //self.lTemps.text = self.tempsStr
        
        if let dat = self.data {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                
                self.lDistancia.text = NSString(format: "%7.2f", dat.distancia) as String
                self.lPedometerDistance.text = NSString(format: "%7.2f", dat.distanciaPedometer) as String
                self.lAltura.text = NSString(format: "%5.0f +/- %5.2f", dat.altura, dat.vdop) as String
                self.lAscent.text = NSString(format: "%5.0f", dat.ascent) as String
                self.lDescent.text = NSString(format: "%5.0f", dat.descent) as String
                
                self.lwDistancia.text = NSString(format: "%7.2f", dat.distancia-dat.wDistancia) as String
                self.lwAscent.text = NSString(format: "%5.0f", dat.ascent-dat.wAscent) as String
                self.lwDescent.text = NSString(format: "%5.0f", dat.descent - dat.wDescent) as String
            })
        }
        
    }
    
    
    @IBAction func openSettings()
    {
        
    }
    
    
    //MARK: - CLLocationManagerDelegate
    
    
    
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == "sSettingsSegue"
        {
            NSLog("Hello Segue")
        }
    }
    
    
}

