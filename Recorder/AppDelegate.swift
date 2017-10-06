//
//  AppDelegate.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 30/1/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit
import WatchConnectivity
import HealthKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UIAlertViewDelegate{
    
    
    let kiCloudChanged = "iCloudChanged"
    var window: UIWindow?
    var genericAlert : UIAlertView?
    var ubiquityUrl :  URL?
    
    //let serverUrl = "http://www.gorina.es/insert.php"
    let serverUrl = "http://www.gorina.es/traces/insertJSON.php"
    
    var serverSession : URLSession
    var serverQueue : NSMutableArray
    var unsentRequests : NSMutableArray
    //let reachability : Reachability
    
    var rootController : ViewController?
    var dataController : DataController?

    var healthData : HealthAuxiliar?
    
    
    override init()
    {
        debugLaunch("AppDelegate.init enter")
        
       // reachability = Reachability.reachabilityForInternetConnection()
        let config = URLSessionConfiguration.ephemeral
        serverSession = URLSession(configuration: config)
        serverQueue = NSMutableArray()
        unsentRequests = NSMutableArray()
        super.init()
        
        healthData = HealthAuxiliar()
        
         
        // If iCloud set iCloud up for copying recorded tracks.
        // Data goes to Traces icloud container :)
        if FileManager.default.ubiquityIdentityToken != nil
        {
            self.checkForiCloud()
        }
        
        debugLaunch("AppDelegate.init exit")
    }
    
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        debugLaunch("AppDelegate didFinishLaunchingWithOptions enter")
          //testImg()  // Just to test icon creation
        debugLaunch("AppDelegate didFinishLaunchingWithOptions enter")

        
        return true
    }
    
    func pushPoint(_ point : NSDictionary){
        serverQueue.enqueue(point);
    }
    
    // force forces the sending of all data independent of connection status.
    // Probably if there is no connection everything will fail+
    // But will be added again and again till we get rid of it
    
    func procesServerQueue(_ force: Bool){
        
        // If we have no connections just do nothing and wait
        
//        if !self.reachability.isReachable() && !force{
//            return;
//        }
        
        return;
        
        // Build new request with pending points
        
        var start = 0
        
        let JSONBody = NSMutableArray(capacity: serverQueue.count+10)
        
        while let tp : NSDictionary = serverQueue.dequeue() as? NSDictionary {
            JSONBody.add(tp)
            if let i = tp.value(forKey: "start") as? Int{
                if i == 1 {
                    start = 1
                }
                else if start == 0 && i == 3{
                    start = 3
                }
            }
        }
        
        let message = NSMutableDictionary()
        
        let uuid = UIDevice.current.identifierForVendor
        message.setValue(uuid!.uuidString, forKey: "dispositivo")
        
        let devName = UIDevice.current.name
        message.setValue(devName, forKey: "deviceName")
        message.setValue(start, forKey: "start")    // Activate start
        message.setValue(JSONBody, forKey: "dades")
        
        
        let bodyData : Data?
        
        do {
            
            bodyData = try  JSONSerialization.data(withJSONObject: message, options: JSONSerialization.WritingOptions())
        } catch _{
            bodyData = nil
        }
        
        
        if let url = URL(string: self.serverUrl) {
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = bodyData
            
            // Add request to unsentRequests
            
            self.unsentRequests.enqueue(request as AnyObject)
            
        }
        
        // Now process unsent requests
        
        while let rq : URLRequest = unsentRequests.dequeue() as? URLRequest{
            
            //let task = serverSession.dataTask(with: <#T##URLRequest#>, completionHandler: <#T##(Data?, URLResponse?, Error?) -> Void#>)
        
            
            let task = serverSession.dataTask(with: rq, completionHandler: { (datas:Data?,  resp: URLResponse?,  err: Error?) -> Void in
                if err != nil {
                    self.unsentRequests.enqueue(rq as AnyObject);        // retry. Perhaps put maxNumber and lastTimeRetried
                }
                else{
                    if let data = datas{
                        let astr = String(data: data, encoding: .utf8)
                        if let str = astr {
                            NSLog("Resposta  : %@", str)
                        }
                        else
                        {
                            NSLog("No Answer")
                        }
                    }
                    else
                    {
                        NSLog("No Data")
                    }
                }
            })
            task.resume()
        }
        
    }
    
    
    func testImg(){
        
        // Primer creem una track
        
        let track = TGLTrack()
        
        let bundle = Bundle.main
        let urls = bundle.url(forResource: "Movescount_track", withExtension: "gpx")
        
        if urls == nil {
            NSLog("URL not loaded")
        }
        
        if let url = urls {
            
            if let data = try? Data(contentsOf: url){
                track.loadData(data, fromFilesystem:FileOrigin.document, withPath:url.path)
                
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
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: { () -> Void in
                
                
                let fileManager = FileManager()
                self.ubiquityUrl = fileManager.url(forUbiquityContainerIdentifier: nil)
                if self.ubiquityUrl == nil{
                    
                    DispatchQueue.main.async(execute: { () -> Void in
                        self.displayMessage("iCloud Not Configured",
                            withTitle:"Error al activar iCloud")
                    })
                }
                else
                {
                    
                    let aNot = Notification(name:Notification.Name(rawValue: self.kiCloudChanged), object:nil)
                    NotificationCenter.default.post(aNot)
                    self.movePendingTracks();
                }
        })
        
        
    }
    
    // Move tracks half written to iCloud so we can see them
    // They shoud be prefixed by X instead of R
    
    
    func movePendingTracks(){
        
        let localTracksUrl = self.localTracksDirectory()
        
        
        let mgr = FileManager()
        
        let enume = mgr.enumerator(at: localTracksUrl,
            includingPropertiesForKeys: nil,
            options:[FileManager.DirectoryEnumerationOptions.skipsSubdirectoryDescendants, FileManager.DirectoryEnumerationOptions.skipsHiddenFiles]) {
                (url :URL, error: Error) -> Bool in
                let err = error as NSError
                NSLog("Error a enumerar fitxers per  %@, %@", url.absoluteString, err)
                return true
        }
        
        
        if let enu : FileManager.DirectoryEnumerator = enume {
            
            while let  url:URL = enu.nextObject() as? URL       {
                if url.pathExtension.uppercased() == "GPX"{
                    
                    //
                    if let name : String = url.lastPathComponent{  // Obtenim el nom!!!
                        
                        let nom = "X" + name.substring(from: name.characters.index(after: name.startIndex))
                        
                        let destUrl = self.applicationDocumentsDirectory().appendingPathComponent(nom)
                        
                        do {
                            try mgr.setUbiquitous(true, itemAt: url, destinationURL: destUrl)
                            
                            NSLog("Recuperat %@", name)
                            
                        }
                        catch _{
                            NSLog("Error al passar al iCLoud ")
                            
                        }
                        
                    }
                }
            }
        }
    }
    
    
    // MARK: - Application life
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
        if let w = self.window{
            if let vcontroller = w.rootViewController as? ViewController{
                if let tim = vcontroller.timer{
                    DispatchQueue.main.async(execute: { () -> Void in
                        tim.invalidate()
                        vcontroller.timer = nil
                    })
                }
            }
        }
    }
    
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        if let w = self.window{
            if let vcontroller = w.rootViewController as? ViewController, let data = self.dataController{
                if data.doRecord != .stopped{
                    DispatchQueue.main.async(execute: { () -> Void in
                        
                        let tim = Timer.scheduledTimer(timeInterval: 1.0, target: vcontroller, selector: #selector(ViewController.updateTime(_:)), userInfo: nil, repeats: true)
                        
                        vcontroller.timer = tim
                        vcontroller.updateTime(tim)
                        vcontroller.updateViewData(nil)
                        
                    })
                    
                    
                }
            }
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    
    func application(_ application: UIApplication,
        handleWatchKitExtensionRequest userInfo: [AnyHashable: Any]?,
        reply: @escaping ([AnyHashable: Any]?) -> Void)
    {
        if let rc = self.dataController{
            if let info = userInfo{
                
                let ops = info["op"] as! String?
                
                if let op = ops
                {
                    switch op {
                        
                    case "start":
                        rc.startRecording()
                        
                    case "stop" :
                        rc.stopRecording()
                        
                        
                    case "pause" :
                        rc.pauseRecording()
                        
                        
                    case "resume" :
                        rc.resumeRecording()
                        
                    case "wp" :
                        rc.doAddWaypoint()
                        
  
                    case "update" :
                        break
                        
                    default:
                        NSLog("Unknown command %@", op)
                        
                        
                    }
                }
            }
        
            var dades : [AnyHashable: Any] = [
                "altura"  : rc.altura,
                "distancia" : rc.distancia,
                "ascent" : rc.ascent,
                "descent" : rc.descent,
                "wDistancia" : rc.distancia - rc.wDistancia,
                "wAscent" : rc.wAscent,
                "wDescent" : rc.wDescent,
                "hr" : rc.HR,
                "state" : rc.doRecord.rawValue]
            
            if let st = rc.startTime {
                dades["startTime"] = st
            }
            else{
                dades["startTime"] = Date()
            }
            
            if let st = rc.wStartTime {
                dades["wStartTime"] = st
            }
            else{
                dades["wStartTime"] = dades["startTime"]
            }
            
            
            
            reply(dades)
             
        }
        
    }
    
    //MARK: - Utilities
    
    
    func displayMessage(_ msg : String,  withTitle title: String)
    {
        self.genericAlert =  UIAlertView(title: title, message: msg, delegate: self, cancelButtonTitle: "OK")
        
        if let alert = self.genericAlert{
            DispatchQueue.main.async(execute: { () -> Void in
                alert.show()
            })
        }
    }
    
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        if alertView == self.genericAlert
        {
            alertView.dismiss(withClickedButtonIndex: buttonIndex, animated: true)
        }
    }
    
    
    func localTracksDirectory() -> URL
    {
        let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).last!
        
        
        if !FileManager.default.fileExists(atPath: path){
            
            
            do {
                
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch _{
                NSLog("Unresolved error")
                abort()
                
            }
        }
        
        let docs = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last!
        
        return docs
        
        
    }
    
    func applicationDocumentsDirectory() -> URL{
        
        if let url = self.ubiquityUrl{
            return url.appendingPathComponent("Documents")
        }
        else{
            return self.localTracksDirectory()
        }
    }
        
    
}
