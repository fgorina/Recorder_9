//
//  InterfaceController.swift
//  Recorder WatchKit Extension
//
//  Created by Francisco Gorina Vanrell on 9/9/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import WatchKit
import Foundation

enum appState : Int{
    case Stopped = 0
    case Recording
    case Paused
}

class InterfaceController: WKInterfaceController {
    
    @IBOutlet weak  var startButton : WKInterfaceButton!
    @IBOutlet weak  var workoutTimer :WKInterfaceTimer!
    @IBOutlet weak  var lapTimer : WKInterfaceTimer!
    @IBOutlet weak  var distLabel : WKInterfaceLabel!
    @IBOutlet weak  var distLapLabel : WKInterfaceLabel!
    
    var timer : NSTimer?
    
    var state : appState = .Stopped
    var op_queue = NSMutableArray()

    
    
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        distLabel.setText("XIM")
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        
        startTimer()
        
        if self.state == .Recording{
            workoutTimer.start()
            lapTimer.start()
        }
        else
        {
            workoutTimer.stop()
            lapTimer.stop()
        }

        super.willActivate()
    }
    
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        
        if let tim = timer {
            tim.invalidate()
            timer = nil
        }
        super.didDeactivate()
    }
    
    func startTimer()
    {
        
        if let tim = self.timer where tim.valid {
            return
        }
        else{
         self.timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "doUpdate:", userInfo: nil, repeats: true)
        }
    }
    
    @IBAction func pause()
    {
        self.startButton.setBackgroundImageNamed("pause_64")
        self.workoutTimer.stop()
        self.lapTimer.stop()
        self.state = .Paused
        
        
    }
    
    @IBAction func stop()
    {
        doCallRecorder("stop")
        doStop()
        
    }
    
    @IBAction func start()
    {
        switch self.state
        {
            
        case .Stopped:
            doCallRecorder("start")
            doStart()
            
        case .Recording:
            doWp()
            
        case .Paused:
            doResume()
            
            
        }
        
    }
    
    func doStart()
    {
        /// Do start function with Recorder
        
        self.state = .Recording
        self.startButton.setBackgroundImageNamed("record_wp_64")
        self.workoutTimer.setDate(NSDate())
        self.workoutTimer.start()
        
        
    }
    
    func doStop(){
        self.state = .Stopped
        self.startButton.setBackgroundImageNamed("record_64")
        self.workoutTimer.stop()
        self.lapTimer.stop()

    }
    
    
    func doWp()
    {
        doCallRecorder("wp")
        self.lapTimer.setDate(NSDate())
        self.lapTimer.start()
    }
    
    func doResume()
    {
        doCallRecorder("resume")
        self.startButton.setBackgroundImageNamed("record_wp_64")
        self.workoutTimer.start()
        self.lapTimer.start()
        self.state = .Recording
    }
    
    
    func doCallRecorder(op : String){
        self.op_queue.enqueue(op)
        
    }

    func callRecorder(){
        
        while let op = op_queue.dequeue(){
            WKInterfaceController.openParentApplication(["op" : op]) { (data : [NSObject : AnyObject], error :NSError?) -> Void in
                self.updateData(data)
            }
        }
    }
    
    func doUpdate(timer : NSTimer?){
        
        // check if free is free
        
        if self.op_queue.count == 0{
            doCallRecorder("update")
        }
        
        self.callRecorder()
        
     }
    
    func updateData(dades : [NSObject : AnyObject]){
        
        if let istate : Int = dades["state"] as? Int{
            
            if let stat : appState = appState(rawValue: istate){

                switch stat {
                    
                case .Stopped :
                    if self.state != .Stopped{
                        self.doStop()
                    }
                    
                case .Paused :
                    
                    if self.state != .Paused{
                        self.pause()
                    }
                    
                    
                case .Recording :
                    if self.state != .Recording{
                        self.doStart()
                    }
                    
                }
                
  
            }
            
        }
        
       
        
        if let v : NSDate = dades["startTime"] as? NSDate{
            if self.state == .Recording{
                workoutTimer.setDate(v)
                workoutTimer.start()
            }
            else
            {
                workoutTimer.stop()
            }
        }
        
        if let v : NSDate = dades["wStartTime"] as? NSDate{
            if self.state == .Recording{
                lapTimer.setDate(v)
                lapTimer.start()
            }
            else{
                lapTimer.stop()
            }
        }
        
        
        if let v : Double = dades["distancia"] as? Double{
            
            if v < 1000.0 {
                
                let units = WKInterfaceDevice.currentDevice().screenBounds.width >= 156.0 ? "m" : ""
                distLabel.setText(NSString(format: "%3.0f%@", v, units) as String)
            }
            else{
                let units = WKInterfaceDevice.currentDevice().screenBounds.width >= 156.0 ? "Km" : ""
                distLabel.setText(NSString(format: "%5.2f%@", v/1000.0, units) as String)
            }
        }
        
        if let v : Double = dades["wDistancia"] as? Double{
            
            if v < 1000.0 {
                let units = WKInterfaceDevice.currentDevice().screenBounds.width >= 156.0 ? "m" : ""
                distLapLabel.setText(NSString(format: "%3.0f%@", v, units) as String)
                
                        
            }
            else{
                let units = WKInterfaceDevice.currentDevice().screenBounds.width >= 156.0 ? "Km" : ""
                distLapLabel.setText(NSString(format: "%5.2f%@", v/1000.0, units) as String)
            }
        }
        
        
        if let v : Int = dades["hr"] as? Int{
            
            self.startButton.setTitle(String(format: "%ld", v))
        }
        
        
    }
    
}
