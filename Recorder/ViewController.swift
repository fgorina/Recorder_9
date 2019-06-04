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
import CoreBluetooth



class ViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var lTemps: UILabel!
    @IBOutlet weak var lDistancia: UILabel!
    @IBOutlet weak var lSpeed: UILabel!
    @IBOutlet weak var lSlope: UILabel!
    @IBOutlet weak var lVAM: UILabel!
    @IBOutlet weak var lPedometerDistance: UILabel!
    @IBOutlet weak var lAscent: UILabel!
    @IBOutlet weak var lAltura: UILabel!
    @IBOutlet weak var lErrorAltura: UILabel!
    @IBOutlet weak var lDescent: UILabel!
    @IBOutlet weak var lHR: UILabel!
    @IBOutlet weak var hrDevice : UILabel!
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
    
    weak var timer : Timer?
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
    
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        debugLaunch("ViewController init nibname enter")
       
        commonInit()
        
        debugLaunch("ViewController init nibname exit")

    }
    
    func commonInit(){
        
        debugLaunch("ViewController commonInit entered")
        
        let del = UIApplication.shared.delegate as! AppDelegate
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
                act.isHidden = false
            }
        }
        
        // Update data to the one in the data controller
        
        if let dat = self.data {
            let state : appState = dat.doRecord
            
            switch state {
                
                
            case .stopped :
                self.stopRecording()
                
            case .recording :
                self.startRecording()
                
            case .paused :
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
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.conexionActive(_:)), name: NSNotification.Name(rawValue: TMKHeartRateMonitor.kSubscribedToHRStartedNotification), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.conexionClosed(_:)), name: NSNotification.Name(rawValue: TMKHeartRateMonitor.kSubscribedToHRStopedNotification), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.hrReceived(_:)), name: NSNotification.Name(rawValue: DataController.kHRUpdated), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.updateState(_:)), name: NSNotification.Name(rawValue: DataController.kAppStateUpdated), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.updateActivity), name: NSNotification.Name(rawValue: DataController.kActivityUpdated), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.updateViewData(_:)), name: NSNotification.Name(rawValue: DataController.kDataUpdated), object: nil)
        
        
    }
    
    @objc func conexionActive(_ not : Notification){
        
        NSLog("Notification %@", not.description)
        self.heartOn = true
        
        if let peripheral = not.object as? CBPeripheral {
            
            self.hrDevice.text = peripheral.name
            
            
        }
        
        let img : UIImage? = UIImage(named: "record_heart_on_64.png")
        self.bStartStop.setImage(img, for: UIControl.State())
    }
    
    @objc func conexionClosed(_ not : Notification){
        NSLog("Notification %@", not.description)
        var imageName = "record_64"
        
        if let record = self.data?.doRecord {
            if record == .recording{
                imageName = "record_on_64"
                
            }
        }
        
        self.heartOn = false
        self.bStartStop.setImage(UIImage(named: imageName), for: UIControl.State())
        self.hrDevice.text = ""
        
    }
    
    @objc func hrReceived(_ not : Notification)
    {
        if let value = not.object as? Int{
            if UIApplication.shared.applicationState == UIApplication.State.active{
                
                DispatchQueue.main.async(execute: { () -> Void in
                    let txt = NSString(format: "%d bpm", value)
                    self.lHR.text = txt as String;
                    
                    if let dat = self.data{
                    if self.heartOn  && dat.doRecord == .recording{
                        self.bStartStop.setImage(UIImage(named: "record_heart_64.png"), for: UIControl.State())
                        self.heartOn = !self.heartOn
                    }
                    else if dat.doRecord == .recording
                    {
                        self.bStartStop.setImage(UIImage(named: "record_heart_on_64.png"), for: UIControl.State())
                        self.heartOn = !self.heartOn
                    }
                    }
                })
            }
        }
        
        //NSLog("Notification %@", not)
    }
    
    //MARK: - Actions
    
    
    
    @IBAction func  startStop(_ src:AnyObject)
    {
        if let dat = self.data {
            
            if dat.doRecord == .stopped
            {
                dat.startRecording()
            }
            else if dat.doRecord == .recording
            {
                dat.pauseRecording()
            }
            else if dat.doRecord == .paused
            {
                dat.resumeRecording()
            }
            
        }
    }
    
    
    @IBAction func  addWaypoint(_ src:AnyObject)
    {
        
        if let dat = self.data {
            
            if dat.doRecord == .paused {
                dat.stopRecording()
            }
            else
            {
                dat.doAddWaypoint()
            }
        }
    }
    
    
    @objc func updateState(_ notification: Notification)
    {
        
        if let dict = notification.userInfo {
            let state : appState = appState(rawValue: dict["state"] as! Int)!
            
            switch state {
                
                
            case .stopped :
                self.stopRecording()
                
            case .recording :
                self.startRecording()
                
            case .paused :
                self.pauseRecording()
                
            }
        }
    }
    
    
    func pauseRecording(){
        
        DispatchQueue.main.async(execute: { () -> Void in
            self.bStartStop.setImage(UIImage(named: "pause_64"), for: UIControl.State())
            self.wpButton.setImage(UIImage(named: "record_64"), for: UIControl.State())
            self.wpButton.setImage(UIImage(named: "record_on_64"), for: .highlighted)
        })
        
        
    }
    
    func stopRecording(){
        
        DispatchQueue.main.async(execute: { () -> Void in
            if let tim = self.timer{
                tim.invalidate()
                self.timer = nil
            }
            self.bStartStop.setImage(UIImage(named: "record_64"), for: UIControl.State())
            
            self.wpButton.setImage(UIImage(named: "record_wp_64"), for: UIControl.State())
            self.wpButton.setImage(UIImage(named: "record_wp_on_64"), for: .highlighted)
            
            self.wpButton.isHidden = true
        })
        
        
    }
    
    func startRecording(){
        DispatchQueue.main.async(execute: { () -> Void in
            
            if let hrMonitor = self.data?.hrMonitor {
                if hrMonitor.connected {
                    
                    self.bStartStop.setImage(UIImage(named: "record_heart_on_64.png"), for:UIControl.State())
                }
                else
                {
                    self.bStartStop.setImage(UIImage(named: "record_on_64"), for:UIControl.State())
                }
            }
            else
            {
                self.bStartStop.setImage(UIImage(named: "record_on_64"), for:UIControl.State())
            }
            
            self.wpButton.setImage(UIImage(named: "record_wp_64"), for: UIControl.State())
            self.wpButton.setImage(UIImage(named: "record_wp_on_64"), for: .highlighted)
            
            self.wpButton.isHidden = false
            
            if self.timer == nil {
                
                let aTimer = Timer(timeInterval: 1.0, target: self, selector: #selector(ViewController.updateTime(_:)), userInfo: nil, repeats: true)
                let runLoop = RunLoop.current
                runLoop.add(aTimer, forMode:RunLoop.Mode.default)
                self.timer = aTimer
                
            }
        })
        
    }
    
    @objc func updateTime(_ timer : Timer)
    {
        if let dat = self.data{
            if let tim = dat.startTime, let wtim = dat.wStartTime {
                let temps = Date().timeIntervalSince(tim as Date)
                let wtemps = Date().timeIntervalSince(wtim as Date)
                
                self.tempsStr = TGLTrackPoint.stringFromTimeInterval(temps)
                let wTempsStr = TGLTrackPoint.stringFromTimeInterval(wtemps)
                
                DispatchQueue.main.async(execute: { () -> Void in
                    self.lTemps.text = self.tempsStr
                    self.lwTemps.text = wTempsStr
                })
            }
        }
    }
    
    @objc func updateActivity()
    {
        if UIApplication.shared.applicationState == UIApplication.State.active{
            
            DispatchQueue.main.async(execute: { () -> Void in
                
                if let act = self.data?.activity, self.lwActivity != nil {
                    self.lwActivity.text = act.stringDescription
                    let imgName = "act_" + act.stringDescription + "_64"
                    if let img = UIImage(named: imgName)
                    {
                        self.lwActivityButton.setImage(img, for: UIControl.State())
                    }
                }
            })
        }
    }
    
    @objc func updateViewData(_ notification : Notification?)
    {
        
        //self.lTemps.text = self.tempsStr
        
        if let dat = self.data {
            DispatchQueue.main.async(execute: { () -> Void in
                
                self.lDistancia.text = NSString(format: "%7.2f", dat.distancia) as String
                self.lPedometerDistance.text = NSString(format: "%7.2f", dat.distanciaPedometer) as String
                self.lAltura.text = NSString(format: "%5.0f +/- %5.2f", dat.altura, dat.vdop) as String
                self.lAscent.text = NSString(format: "%5.0f", dat.ascent) as String
                self.lDescent.text = NSString(format: "%5.0f", dat.descent) as String
                
                self.lwDistancia.text = NSString(format: "%7.2f", dat.distancia-dat.wDistancia) as String
                self.lwAscent.text = NSString(format: "%5.0f", dat.ascent-dat.wAscent) as String
                self.lwDescent.text = NSString(format: "%5.0f", dat.descent - dat.wDescent) as String
                
                // Spped in m/s -> km/h
                
                self.lSpeed.text = NSString(format: "%7.1f Km/h", dat.speed * 3.6) as String
                self.lSlope.text = NSString(format: "%7.1f %%", dat.slope*100.0) as String
                self.lVAM.text = NSString(format: "%5.0f m/h", dat.VAM) as String
           })
        }
        
    }
    
    
    @IBAction func openSettings()
    {
        
    }
    
    
    //MARK: - CLLocationManagerDelegate
    
    
    
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "sSettingsSegue"
        {
            NSLog("Hello Segue")
        }
    }
    
    
}

