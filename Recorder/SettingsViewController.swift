//
//  SettingsViewController.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 17/8/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {

    @IBOutlet weak var sTransmit: UISwitch!
    @IBOutlet weak var sBlock: UISwitch!
    
    @IBOutlet weak var fUser: UITextField!
    @IBOutlet weak var fPassword: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBAction func switchTransmit(_ src : AnyObject){
        let val = sTransmit.isOn
        NSLog("Switch Transmit")
    
    }
    
    @IBAction func switchBlock(_ src : AnyObject){
        let val = sBlock.isOn
        NSLog("Switch Transmit")
        
        UIApplication.shared.isIdleTimerDisabled = val
   }
    
    @IBAction func login(_ src : AnyObject){
        NSLog("Switch Transmit")
        
    
    }


    @IBAction func closeSettings()
    {
        self.dismiss(animated: true, completion: { () -> Void in
            NSLog("Dismissing Settings")
        })
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
