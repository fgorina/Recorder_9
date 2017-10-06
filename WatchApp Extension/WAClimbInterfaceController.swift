//
//  WAClimbInterfaceController.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 15/10/15.
//  Copyright © 2015 Paco Gorina. All rights reserved.
//

import WatchKit
import Foundation


class WAClimbInterfaceController: WKInterfaceController {
        
        
        @IBOutlet weak  var startButton : WKInterfaceButton!
        @IBOutlet weak  var workoutTimer :WKInterfaceTimer!
        @IBOutlet weak  var lapTimer : WKInterfaceTimer!
        @IBOutlet weak  var distLabel : WKInterfaceLabel!
        @IBOutlet weak  var heightLabel : WKInterfaceLabel!
        @IBOutlet weak  var unitsLabel : WKInterfaceLabel!
        //@IBOutlet weak  var hrCounterLabel : WKInterfaceLabel!
        @IBOutlet weak  var hrlabel : WKInterfaceLabel!
        
        @IBOutlet weak var sessionOnLabel : WKInterfaceImage!
        
        weak var rootController : WAInterfaceController?
        
        override func awake(withContext context: Any?) {
            super.awake(withContext: context)
            
            self.rootController  = WKExtension.shared().rootInterfaceController as? WAInterfaceController
            
            
            // Configure interface objects here.
        }
        
        override func willActivate() {
            // This method is called when watch view controller is about to be visible to user
            super.willActivate()
            
            if let root = WKExtension.shared().rootInterfaceController as? WAInterfaceController {
                root.actualPageController = self
            }
            
            self.updateFields()
        }
        
        override func didDeactivate() {
            // This method is called when watch view controller is no longer visible
            super.didDeactivate()
        }
        
        
        //MARK: Update Screen data
    }
    
    extension WAClimbInterfaceController : WAInterfaceNavigation{
        
        func updateFields(){
            
            DispatchQueue.main.async(execute: { () -> Void in
                
                
                if let time = self.rootController?.startTime {
                    self.workoutTimer.setDate(time as Date)
                    if self.rootController?.state == .recording{
                        self.workoutTimer.start()
                    }
                    else{
                        self.workoutTimer.stop()
                    }
                }
                
                if let time = self.rootController?.wStartTime {
                    self.lapTimer.setDate(time as Date)
                    if self.rootController?.state == .recording{
                        self.lapTimer.start()
                    }
                    else{
                        self.lapTimer.stop()
                    }
                }
                
                
                if let v = self.rootController?.distancia {
                    if v < 1000.0 {
                        
                        let units = "m"
                        self.distLabel.setText(String(format: "%3.0f%@", v, units))
                    }
                    else{
                        let units = "Km"
                        self.distLabel.setText(String(format: "%5.2f%@", v/1000.0, units))
                    }
                    
                }
                
                if let v = self.rootController?.wDistancia {
                    if v < 1000.0 {
                        
                        let units = "m"
                        self.hrlabel.setText(String(format: "%3.0f%@", v, units))
                    }
                    else{
                        let units = "Km"
                        self.hrlabel.setText(String(format: "%5.2f%@", v/1000.0, units))
                    }
                }
                
                if let v = self.rootController?.altura {
                    
                    let s = String(format: "%4.0f%@", v, "m")
                    self.heightLabel.setText(s)
                }
                
                if let v = self.rootController?.ascentSpeed, let v1 = self.rootController?.descentSpeed {
                    
                    let speed = (v-v1) * 3600.0
                    let s = String(format: "%4.0f%@", speed, " m/h")
                    self.unitsLabel.setText(s)
                }
                
                
                //  var stateIcon = "record_64"
                
                if let stat = self.rootController?.state{
                    switch stat{
                        
                    case .stopped:
                        //stateIcon = "record_64"
                        // self.startButton.setBackgroundImageNamed(stateIcon)
                        self.heightLabel.setText("START")
                        self.unitsLabel.setText("")
                    case .paused:
                        //stateIcon = "pause_64"
                        //self.startButton.setBackgroundImageNamed(stateIcon)
                        self.heightLabel.setText("Paused")
                        self.unitsLabel .setText("")
                    case .recording:
                        //stateIcon = "record_wp_64"
                        //self.startButton.setBackgroundImage(nil)
                        //self.unitsLabel.setText("min/km")
                        break
                        
                    }
                }
            })
        }
        
        
        
}
