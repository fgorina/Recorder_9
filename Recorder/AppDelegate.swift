//
//  AppDelegate.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 30/1/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UIAlertViewDelegate {
    
    
    let kiCloudChanged = "iCloudChanged"
    var window: UIWindow?
    var genericAlert : UIAlertView?
    var ubiquityUrl :  NSURL?
    
    //let serverUrl = "http://www.gorina.es/insert.php"
    let serverUrl = "http://www.gorina.es/traces/insertJSON.php"

    var serverSession : NSURLSession
    var serverQueue : NSMutableArray
    var unsentRequests : NSMutableArray
    let reachability : Reachability
    
    override init()
    {
        
        reachability = Reachability.reachabilityForInternetConnection()
        let config = NSURLSessionConfiguration.ephemeralSessionConfiguration()
        serverSession = NSURLSession(configuration: config)
        serverQueue = NSMutableArray()
        unsentRequests = NSMutableArray()
        
        super.init()
    }
    
    
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        // If iCloud set iCloud up for copying recorded tracks.
        // Data goes to Traces icloud container :)
        
        if NSFileManager.defaultManager().ubiquityIdentityToken != nil
        {
            self.checkForiCloud()
        }
        
        testImg()
        
        return true
    }
    
    func pushPoint(point : NSDictionary){
        serverQueue.enqueue(point);
    }
    
    // force forces the sending of all data independent of connection status.
    // Probably if there is no connection everything will fail+
    // But will be added again and again till we get rid of it
    
    func procesServerQueue(force: Bool){
        
        // If we have no connections just do nothing and wait
        
        if !self.reachability.isReachable() && !force{
            return;
        }
        
        // Build new request with pending points
        
        var start = 0
        
        var JSONBody = NSMutableArray(capacity: serverQueue.count+10)
        
        while let tp : NSDictionary = serverQueue.dequeue() as? NSDictionary {
            JSONBody.addObject(tp)
            if let i = tp.valueForKey("start") as? Int{
                if i == 1 {
                    start = 1
                }
                else if start == 0 && i == 3{
                    start = 3
                }
            }
         }
        
        let message = NSMutableDictionary()
        
        let uuid = UIDevice.currentDevice().identifierForVendor
        message.setValue(uuid.UUIDString, forKey: "dispositivo")

        let devName = UIDevice.currentDevice().name
        message.setValue(devName, forKey: "deviceName")
        message.setValue(start, forKey: "start")    // Activate start
        message.setValue(JSONBody, forKey: "dades")
        
        
        var err : NSError?
        
        let bodyData : NSData? = NSJSONSerialization.dataWithJSONObject(message, options: NSJSONWritingOptions.allZeros, error: &err)
        
        
        if let url = NSURL(string: self.serverUrl) {
            
            var request = NSMutableURLRequest(URL: url)
            request.HTTPMethod = "POST"
            request.HTTPBody = bodyData
            
            // Add request to unsentRequests
            
            self.unsentRequests.enqueue(request)
            
        }
        
        // Now process unsent requests
        
        while let rq : NSMutableURLRequest = unsentRequests.dequeue() as? NSMutableURLRequest{
            var task = serverSession.dataTaskWithRequest(rq, completionHandler: { (data:NSData!,  resp: NSURLResponse!,  err: NSError!) -> Void in
                if err != nil {
                    self.unsentRequests.enqueue(rq);        // retry. Perhaps put maxNumber and lastTimeRetried
                }
                else{
                    var astr = NSString(data: data, encoding: NSUTF8StringEncoding)
                    if let str = astr {
                        NSLog("Resposta  : %@", str)
                    }
                    else
                    {
                        NSLog("No Answer")
                    }
                }
            })
            task.resume()
          }

    }
    
    
    func testImg(){
        
        // Primer creem una track
        
        let track = TGLTrack()
        
        let bundle = NSBundle.mainBundle()
        let urls = bundle.URLForResource("Movescount_track", withExtension: "gpx")
        
        if urls == nil {
            NSLog("URL not loaded")
        }
        
        if let url = urls {
            
            if let data = NSData(contentsOfURL: url){
                track.loadData(data, fromFilesystem:FileOrigin.Document, withPath:url.path!)
                
                 if track.data.count == 0{
                    NSLog( "Error in number of points in track")
                }
                
                let img = track.imageWithWidth(250, height:250)
                
                let w = img.size.width
                let h = img.size.height
                
                if w != 250 || h != 250 {
                    NSLog("Medidas erroneas")
                }
             }
        }
    }
    
    
    func checkForiCloud()
    {
        // obtaining the URL for our ubiquity container could potentially take a long time,
        // so dispatch this call so to not block the main thread
        //
        
        // Primer podriem mfer servir el identity Token ?
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
            0), { () -> Void in
                
                
                let fileManager = NSFileManager()
                self.ubiquityUrl = fileManager.URLForUbiquityContainerIdentifier(nil)
                if self.ubiquityUrl == nil{
                    
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.displayMessage("iCloud Not Configured",
                            withTitle:"Error al activar iCloud")
                    })
                }
                else
                {
                    
                    let aNot = NSNotification(name:self.kiCloudChanged, object:nil)
                    NSNotificationCenter.defaultCenter().postNotification(aNot)
                    self.movePendingTracks();
                }
        })
        
        
    }
    
    // Move tracks half written to iCloud so we can see them
    // They shoud be prefixed by X instead of R
    
    
    func movePendingTracks(){
        
        let localTracksUrl = self.localTracksDirectory()
        let del = UIApplication.sharedApplication().delegate as! AppDelegate
        
        
        let mgr = NSFileManager()
        var err : NSError?
        
        let enume = mgr.enumeratorAtURL(localTracksUrl,
            includingPropertiesForKeys: nil,
            options:NSDirectoryEnumerationOptions.SkipsSubdirectoryDescendants | NSDirectoryEnumerationOptions.SkipsHiddenFiles) {
                (url :NSURL!, error: NSError!) -> Bool in
                
                NSLog("Error a enumerar fitxers per  %@", url, error)
                return true
        }
        
        var files = Array<NSURL>()
        
        var rsrc : AnyObject?
        var anyError : NSError?
        
        
        if let enu : NSDirectoryEnumerator = enume {
            
            while let  url:NSURL = enu.nextObject() as? NSURL       {
                if url.pathExtension?.uppercaseString == "GPX"{
                    
                    //
                    if let name : String = url.lastPathComponent{  // Obtenim el nom!!!
                        
                        let nom = "X" + name.substringFromIndex(name.startIndex.successor())
                        
                        let destUrl = self.applicationDocumentsDirectory().URLByAppendingPathComponent(nom)
                        mgr.setUbiquitous(true, itemAtURL: url, destinationURL: destUrl, error: &anyError)
                        
                        if let err = anyError{
                            NSLog("Error al passar al iCLoud %@", err)
                        }
                        else{
                            NSLog("Recuperat %@", name)
                        }
                        
                    }
                }
            }
        }
    }
    
    
    // MARK: - Application life
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
        if let w = self.window{
            if let vcontroller = w.rootViewController as? ViewController{
                if let tim = vcontroller.timer{
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        tim.invalidate()
                        vcontroller.timer = nil
                    })
                }
            }
        }
    }
    
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        if let w = self.window{
            if let vcontroller = w.rootViewController as? ViewController{
                if vcontroller.doRecord != .Stopped{
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        
                        let tim = NSTimer.scheduledTimerWithTimeInterval(1.0, target: vcontroller, selector: "updateTime:", userInfo: nil, repeats: true)
                        
                        vcontroller.timer = tim
                        vcontroller.updateTime(tim)
                        vcontroller.updateViewData()
                        
                    })
                    
                    
                }
            }
        }
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    
    //MARK: - Utilities
    
    
    func displayMessage(msg : String,  withTitle title: String)
    {
        self.genericAlert =  UIAlertView(title: title, message: msg, delegate: self, cancelButtonTitle: "OK")
        
        if let alert = self.genericAlert{
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                alert.show()
            })
        }
    }
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        if alertView == self.genericAlert
        {
            alertView.dismissWithClickedButtonIndex(buttonIndex, animated: true)
        }
    }
    
    
    func localTracksDirectory() -> NSURL
    {
        let path = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).last as! String
        
        
        if !NSFileManager.defaultManager().fileExistsAtPath(path){
            var error : NSError? = nil
            
            if !NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil, error: &error){
                NSLog("Unresolved error %@", error!)
                abort()
                
            }
        }
        
        let docs = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).last as! NSURL
        
        return docs
        
        
    }
    
    func applicationDocumentsDirectory() -> NSURL{
        
        if let url = self.ubiquityUrl{
            return url.URLByAppendingPathComponent("Documents")
        }
        else{
            return self.localTracksDirectory()
        }
    }
    
    
}

