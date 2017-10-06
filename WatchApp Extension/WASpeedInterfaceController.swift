//
//  WASpeedInterfaceController.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 8/10/15.
//  Copyright © 2015 Paco Gorina. All rights reserved.
//

import WatchKit
import Foundation


class WASpeedInterfaceController: WKInterfaceController {

    
    @IBOutlet weak  var startButton : WKInterfaceButton!
    @IBOutlet weak  var workoutTimer :WKInterfaceTimer!
    @IBOutlet weak  var lapTimer : WKInterfaceTimer!
    @IBOutlet weak  var distLabel : WKInterfaceLabel!
    @IBOutlet weak  var speedLabel : WKInterfaceLabel!
    @IBOutlet weak  var unitsLabel : WKInterfaceLabel!
    //@IBOutlet weak  var hrCounterLabel : WKInterfaceLabel!
    @IBOutlet weak  var distLapLabel : WKInterfaceLabel!
    
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
        
        if let root = self.rootController {
            
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

extension WASpeedInterfaceController : WAInterfaceNavigation{

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
                    self.distLapLabel.setText(String(format: "%3.0f%@", v, units))
                }
                else{
                    let units = "Km"
                    self.distLapLabel.setText(String(format: "%5.2f%@", v/1000.0, units))
                }
            }
            
            if let v = self.rootController?.speed {
                
                var pace = 0.0
                
                if v > 0.03 {
                    pace = 1000.0 / v       // Pace in seconds
                }
                
                let minutes = Int(floor(pace / 60.0))
                let seconds = Int(floor(pace - (Double(minutes) * 60.0)))
                
                let s = String(format: "%d:%d", minutes, seconds)
                
                self.speedLabel.setText(s)
            }
            
            //  var stateIcon = "record_64"
            
            if let stat = self.rootController?.state{
                switch stat{
                    
                case .stopped:
                    //stateIcon = "record_64"
                    // self.startButton.setBackgroundImageNamed(stateIcon)
                    self.speedLabel.setText("START")
                    self.unitsLabel.setText("")
                case .paused:
                    //stateIcon = "pause_64"
                    //self.startButton.setBackgroundImageNamed(stateIcon)
                    self.speedLabel.setText("Paused")
                    self.unitsLabel .setText("")
                case .recording:
                    //stateIcon = "record_wp_64"
                    //self.startButton.setBackgroundImage(nil)
                    self.unitsLabel.setText("min/km")
                    
                }
            }
        })
    }

    
    
}
