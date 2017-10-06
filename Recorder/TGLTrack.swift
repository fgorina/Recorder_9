//
//  TGLTrack.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 1/2/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit
import MapKit
import AssetsLibrary
import CoreMotion
import HealthKit



public enum FileOrigin {
    case document
    case dropbox
}

open class TGLTrack: NSObject, XMLParserDelegate {
    
    // Some Constants
    
    let DISTANCE = 0.0 // 10.0 m
    let TEMPS = 0.0     // 5.0 s
    
    var lastTimeSent : Date?  = nil // Last time data sent
    var deltaSend : Double = 60.0     // Send every minute!!!
    
    
    
    // Some local data for the XML parser
    
    var buildingChars = NSMutableString()
    var point : TGLTrackPoint?
    var firstPoint = false
    var oldPoint : TGLTrackPoint?
    var wpt = false
    var filterHeightLevel = 2
    var filterSpeedLevel = 5
    var filterBpmLevel = 0
    var lapTime : Double = 0.0
    
    var dateFormatter = ISO8601DateFormatter()
    
    
    
    //var colorString = "0000ff"
    
    
    // Some public data
    
    open var data  = Array<TGLTrackPoint>()      // Points that form the track
    open var waypoints  = Array<TMKWaypoint>() // Sustituir posteriorment per Waypoints
    open var laps = Array<Double>()        // Laps en Suunto
    //public var laps = Array<TGLTrackPoint>() // Ni idea que es
    
    // Document data
    
    open var name = "New Track"     // Name of the track
    open var color = UIColor.green    // Color of the track
    open var doc : TMKTrackDocument? = nil   // UIDocument si origin es document
    open var origin = FileOrigin.document    // Tipus de origin del fitxer
    open var path : String?                  // Si Document es Url si Dropbox es DBPath
    
    // Envelop data
    
    var minLat : CLLocationDegrees = 0.0
    var maxLat : CLLocationDegrees = 0.0
    var minLon : CLLocationDegrees = 0.0
    var maxLon : CLLocationDegrees = 0.0
    
    var totalAscent = 0.0
    var totalDescent = 0.0
    
    // Recording file data -- Usually es written to a local file first
    
    var hdl : FileHandle?
    var lastPointWritten : Int = 0
    
    // Some constants and accessories
    
    var stringColor : String {
        var red : CGFloat = 0.0
        var green : CGFloat = 0.0
        var blue : CGFloat = 0.0
        var alfa : CGFloat = 0.0
        
        
        self.color.getRed(&red, green: &green, blue: &blue, alpha: &alfa);
        
        let sred : UInt32 = UInt32(floor(red*255))
        let sgreen : UInt32 = UInt32(floor(green*255))
        let sblue : UInt32 = UInt32(floor(blue*255))
        
        let str = String(format:"%02x%02x%02x", sred, sgreen, sblue)
        
        return str
    }
    
    let xmlHeader : String = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<gpx xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.cluetrust.com/XML/GPXDATA/1/0 http://www.cluetrust.com/Schemas/gpxdata10.xsd http://www.gorina.es/XML/TRACESDATA/1/0/tracesdata.xsd\" xmlns:gpxdata=\"http://www.cluetrust.com/XML/GPXDATA/1/0\" xmlns:tracesdata=\"http://www.gorina.es/XML/TRACESDATA/1/0\" version=\"1.1\" creator=\"Traces - http://www.gorina.es/traces\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"
    
    let xmlFooter = "</trkseg>\n</trk>\n</gpx>\n"
    
    
    var trackHeader : String {
        return "<trk>\n<name>\(self.name)</name>\n<color>\(self.stringColor)</color>\n<trkseg>\n"
    }
    
    var xmlText : String  {
        
        var str = self.xmlHeader
        
        for wp in self.waypoints {
            str += wp.xmlText
        }
        
        str += self.trackHeader
        
        for tp in self.data {
            str += tp.xmlText
        }
        str +=  self.xmlFooter
        
        return str
        
    }
    
    public override init()
    {
        // let enUSPOSIXLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        
        super.init()
    }
    
    open class func newTrackWithURL(_ url:URL) -> (TGLTrack)
    {
        let tr  = TGLTrack();
        
        // tr.name = NSLocalizedString(@"New Track", "Nova Traça"); ??? Com es fa ara?
        
        
        tr.path = url.path;
        let nom = url.lastPathComponent
        tr.name = nom
        
        //[tr updateBoundingBox];
        
        return tr;
    }
    
    // MARK : - Loading Data
    
    open func loadURL(_ url:URL, fromFilesystem fs:FileOrigin)
    {
        
        
        
        if let parser = XMLParser(contentsOf: url)
        {
            parser.delegate = self
            parser.parse()
        }
        
        self.origin = fs
        self.path = url.absoluteString
        
        // TODO : Veure si aqui necessitem el filtering
        
        // Construim 2 wp un amb el primer punt i un altre amb el ultim i els afegin
        
        
        // [self updateBoundingBox];
        
        // Afegir els punts inicials i finals
        
        
        if let  tp = self.data.first {
            let wp = TMKWaypoint.newWaypointFromTrackPoint(_trackPoint: tp)
            wp.title = "Start";
            wp.track = self;
            wp.type = WaypointType.start
            
            self.waypoints.insert(wp, at: 0)
        }
        
        if let tp = self.data.last {
            let wp = TMKWaypoint.newWaypointFromTrackPoint(_trackPoint: tp)
            wp.title = "End";
            wp.track = self;
            wp.type = WaypointType.end
            self.waypoints.append(wp)
            
            
        }
        
        
        self.updateBoundingBox()
        
        // TODO : Si es necessari afegir la notificacio de creació
        /*
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"YES", @"WAYPOINTS", @"NO", @"CENTER", nil];
        NSNotification *notification = [NSNotification notificationWithName:kTrackUpdatedNotification object:self userInfo:userInfo];
        [[NSNotificationCenter defaultCenter] postNotification:notification];
        [self addToHealthKit];
        */
        
    }
    
    
    
    open func loadData(_ data : Data, fromFilesystem fs:FileOrigin, withPath path:String)
    {
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        self.origin = fs
        self.path = path
        
        if self.data.count > 0 {
            
            // TODO: Veure si apliquem el filtering
            /*
            [self filterSpeed:self.filterSpeedLevel];
            [self filterHeight:self.filterHeightLevel];
            [self filterHeartRate:self.filterBpmLevel];
            */
            //[self deselect]; No es nedessari a aquesta aplicacio
            
            // Inserir waypoints al començament i final
            
            if let  tp = self.data.first {
                let wp = TMKWaypoint.newWaypointFromTrackPoint(_trackPoint: tp)
                wp.title = "Start";
                wp.track = self;
                wp.type = WaypointType.start
                
                self.waypoints.insert(wp, at: 0)
            }
            
            if let tp = self.data.last {
                let wp = TMKWaypoint.newWaypointFromTrackPoint(_trackPoint: tp)
                wp.title = "End";
                wp.track = self;
                wp.type = WaypointType.end
                self.waypoints.append(wp)
                
                
            }
            
            
            self.updateBoundingBox()
            
            
            // TODO: Send notifications?
            /*
            NSNotification *notification = [NSNotification notificationWithName:kTrackUpdatedNotification object:self userInfo:nil];
            
            [[NSNotificationCenter defaultCenter] postNotification:notification];
            
            [self addToHealthKit];
            */
            
        }
    }
    
    // MARK: - Writing to disk
    
    func newRecordingName() -> String
    {
        
        let store = UserDefaults.standard
        var oldPath = store.string(forKey: "XRECORDINGPATH")
        
        // Si oldPath existeix es que ha petat la gravació. Recuperem les dades
        var newName : String = "new track.gpx"
        oldPath = nil   // Desactivem
        
        if let path = oldPath { // Desactivat per tests
            newName = NSString(string: path).lastPathComponent
        }
        else
        {
            let ldateFormatter = DateFormatter()
            let enUSPOSIXLocale = Locale(identifier: "en_US_POSIX")
            
            ldateFormatter.locale = enUSPOSIXLocale
            ldateFormatter.dateFormat = "'R_'yyyyMMdd'_'HHmmss'_Track.gpx'"
            newName = ldateFormatter.string(from: Date())
        }
        return newName
    }
    
    
    open func writeToURL(_ url : URL) -> (Bool)
    {
        //let cord : NSFileCoordinator = NSFileCoordinator(filePresenter: self.doc)
        //var error : NSError?
        
        //        cord.coordinateWritingItemAtURL(url,
        //           options: NSFileCoordinatorWritingOptions.ForReplacing,
        //          error: &error)
        //          { ( newURL :NSURL!) -> Void in
        
        // Check if it exits
        
        let mgr =  FileManager()
        
        
        
        let exists = mgr.fileExists(atPath: url.path)
        
        if !exists{
            mgr.createFile(atPath: url.path, contents: "Hello".data(using: String.Encoding.utf8), attributes:nil)
        }
        
        
        
        if let hdl = FileHandle(forWritingAtPath: url.path){
            hdl.truncateFile(atOffset: 0)
            hdl.write(self.xmlHeader.data(using: String.Encoding.utf8)!)
            
            for wp in self.waypoints {
                if wp.type != WaypointType.start && wp.type != WaypointType.end{
                    hdl.write(wp.xmlText.data(using: String.Encoding.utf8)!)
                }
            }
            
            hdl.write(self.trackHeader.data(using: String.Encoding.utf8)!)
            
            for tp in self.data {
                hdl.write(tp.xmlText.data(using: String.Encoding.utf8)!)
            }
            
            hdl.write(self.xmlFooter.data(using: String.Encoding.utf8)!)
            hdl.closeFile()
            return true
        }
        else
        {
            return false
            //error = err
        }
        
        //   } Fora manager
        
    }
    
    func openRecording()
    {
        // Get new name or old if not closed OK
        
        let del  = UIApplication.shared.delegate as! AppDelegate
        
        let url = del.localTracksDirectory().appendingPathComponent(self.newRecordingName())
        
        let store = UserDefaults.standard
        store.set(url.path, forKey:"XRECORDINGPATH")
        store.synchronize()
        
        // set our path and name to new data
        
        self.path = url.path
        
        let nom = url.lastPathComponent
        self.name = nom
        
        
        // If file exists go to end of file. If not create it
        
        
        let path = url.path
            if FileManager.default.fileExists(atPath: path){
                
                do{
                    
                    self.hdl =  try FileHandle(forWritingTo: url)
                    if let hd = self.hdl {
                        hd.seekToEndOfFile()
                    }
                }
                    
                catch _{
                    
                }
            }
            else{
                
                FileManager.default.createFile(atPath: path, contents:self.xmlHeader.data(using: String.Encoding.utf8), attributes:nil)
                
                do {
                    self.hdl = try FileHandle(forWritingTo: url)
                    
                    if let hd = self.hdl{
                        hd.seekToEndOfFile()
                        hd.write(self.trackHeader.data(using: String.Encoding.utf8)!)
                    }
                }
                catch _{
                    
                }
            }
            
            self.lastPointWritten = -1;
            
        
    }
    
    
    func closeRecording(_ heartRates : [HKQuantitySample]?)
    {
        
        self.updateBoundingBox()
        
        if let hd = self.hdl{
            hd.write(self.xmlFooter.data(using: String.Encoding.utf8)!)
            hd.closeFile()
            self.hdl = nil
        }
        
        if let pth = self.path {
            if self.data.count < 2  {// No Data!!! De moment canviar per fer proves
                do {
                    try FileManager.default.removeItem(atPath: pth)
                }
                catch _{
                    NSLog("Error al esborrar arxiu %@", pth)
                }
            }
            else
            {
                
                if let ha = heartRates{  // Update Heart Rates
                    if self.updateHR(ha, force:true){
                        self.writeToURL( URL(fileURLWithPath: pth))
                    }
                }
                
                let thumb = self.imageWithWidth(256, height: 256)
                
                let name = NSString(string: pth).lastPathComponent  // Obtenim el nom!!!
                let del = UIApplication.shared.delegate as! AppDelegate
                let destUrl = del.applicationDocumentsDirectory().appendingPathComponent(name)
                
                let url = URL(fileURLWithPath: pth)
                do {
                    try (url as NSURL).setResourceValue([URLThumbnailDictionaryItem.NSThumbnail1024x1024SizeKey: thumb],
                        forKey:URLResourceKey.thumbnailDictionaryKey)
                }
                catch _{
                    NSLog("No puc gravar la imatge :)")
                }
                do {
                    try FileManager.default.setUbiquitous(true, itemAt: url, destinationURL: destUrl)
                    
                }catch _{
                    NSLog("Error al passar al iCLoud ")
                }
                
                // Now create a new Workout
                
                if #available(iOS 9.0, *) {
                    self.createWorkout(heartRates)
                }
            }
        }
        
        let store = UserDefaults.standard
        store.removeObject(forKey: "XRECORDINGPATH")
        store.synchronize()
        
        // Now send a processServerQueue so pending points get sent to the Server
        
        let del : AppDelegate = UIApplication.shared.delegate as! AppDelegate
        del.procesServerQueue(true)
        
    }
    
    func totalEnergyBurned () -> Double
    {
            var tot = 0.0
        
        for tp in self.data{
            tot = tot + tp.calories
        }
        
        return tot
        
    }
    
    
    
    @available(iOS 9.0, *)
    
    func createWorkout(_ heartRates : [HKQuantitySample]?){
        
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            
            if let healthStore = delegate.healthData?.healthStore{ // If healthStore exists we are authorized
                
                let tp0 = self.data.first!
                let tp1 = self.data.last!
                let date0 = tp0.dtime
                let date1 = tp1.dtime
                
                let u = HKUnit.meter()
                let d = tp1.distanciaOrigen
                let dist = HKQuantity(unit: u, doubleValue: d)
                
                let cal = HKQuantity(unit: HKUnit.calorie() , doubleValue:totalEnergyBurned())
                
                
                let wk = HKWorkout(activityType: HKWorkoutActivityType.running, start: date0 as Date, end: date1 as Date, duration: date1.timeIntervalSince(date0 as Date), totalEnergyBurned: cal, totalDistance: dist, device: nil, metadata: nil)
                
                healthStore.save(wk, withCompletion: { (done: Bool, err : Error?) -> Void in
                    
                    if done {
                        // Now add the hr samples
                        
                        if let hr = heartRates {
                            
                            healthStore.add(hr, to: wk, completion: { (done : Bool, err : Error?) -> Void in
                                if let er = err as? NSError, !done {
                                    NSLog("Error al afegir samples : %@", er.localizedDescription)
                                    return
                                }
                                
                            })
                        }
                        
                        // Now add calories samples
                        
                        let activeCalType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!
                        
                        var tp0 : TGLTrackPoint?
                        
                        var samples : [HKQuantitySample] = [HKQuantitySample]()
                        
                        for tp in self.data where tp.activeCalories > 0.0{
                            
                            let cal = HKQuantity(unit: HKUnit.calorie() , doubleValue:tp.activeCalories*1000.0)
                            
                            if let tpx = tp0 {
                            
                                let sample = HKQuantitySample(type: activeCalType, quantity: cal, start: tpx.dtime, end: tp.dtime)
                                
                                samples.append(sample)
                          
                            
                            }
                            
                            tp0 = tp
                        }
                        healthStore.add(samples, to: wk, completion: { (done : Bool, err : Error?) -> Void in
                            if let er = err as? NSString, !done {
                                NSLog("Error al afegir samples de calories: %@", er)
                                return
                            }
                        })
                        
                    }
                    else if let er = err as? NSString {
                        NSLog("Error al crear workout : %@", er)
                        return
                    }
                })
                
            }
            
        }
        
    }
    
    func addWaypoint(_ wp : TMKWaypoint){
        
        if let ahdl = self.hdl{
            objc_sync_enter(self.hdl)
            self.waypoints.append(wp)
            if let dat = wp.xmlText.data(using: String.Encoding.utf8){
                ahdl.write(dat)
            }
            objc_sync_exit(self.hdl)
            
        }
    }
    
    
    func addLocations(_ arr: [CLLocation], hr:Int, force:Bool, activity: CMMotionActivity?)
    {
        var pt1 : TGLTrackPoint?
        var pt0 : TGLTrackPoint?
        
        if self.data.count > 0{
            pt0 = self.data[0]
            pt1 = self.data.last
        }
        
        
        
        
        for loc in arr {      // Aniria be tenie en compte l'activitat. SI Indoor accuracy no es important
            if force || (loc.horizontalAccuracy > 0.0 && (loc.horizontalAccuracy < 20.0 ||  (hr != 0 && self.data.count > 0))){
                
                let tp = TGLTrackPoint()
                
                tp.coordinate = CLLocationCoordinate2DMake(loc.coordinate.latitude, loc.coordinate.longitude)
                
                tp.ele = loc.altitude
                tp.dtime = loc.timestamp
                tp.speed = loc.speed
                tp.hPrecision = loc.horizontalAccuracy
                tp.vPrecision = loc.verticalAccuracy
                tp.heading = loc.course
                tp.heartRate = Double(hr)
                tp.filteredHeartRate = Double(hr)
                tp.dtime = loc.timestamp
                
                if let act = activity{
                    tp.activity = act.activEnum()
                }
                
                
                if pt0 == nil{   // Es tracta del primer punt. Fins que no tinguem un bon fixing no fem res
                    tp.tempsOrigen = 0.0
                    tp.distanciaOrigen = 0.0
                    self.totalAscent = 0.0
                    self.totalDescent = 0.0
                    
                    pt0 = tp;
                    pt1 = tp;
                    
                    tp.filteredEle = tp.ele;
                    
                    self.data.append(tp)
                    
                    if GlobalConstants.debug {
                        NSLog("Logged first item");
                    }
                }
                else if pt1 != nil {    // pt0 i pt1 tenen sempre valors.
                    tp.tempsOrigen = tp.dtime.timeIntervalSince(pt0!.dtime)
                    let d = tp.location.distance(from: pt1!.location)
                    let dt = tp.dtime.timeIntervalSince(pt1!.dtime as Date)
                    let dh = tp.ele - pt1!.ele
                    if d >= DISTANCE || dt >= TEMPS {
                        tp.distanciaOrigen = pt1!.distanciaOrigen + tp.location.distance(from: pt1!.location)
                        pt1 = tp
                        tp.filteredEle = tp.ele;
                        
                        if dh > 0.0{
                            self.totalAscent += dh
                        }
                        
                        if dh < 0.0 {
                            self.totalDescent -= dh
                        }
                        
                        
                        self.data.append(tp)
                        if GlobalConstants.debug {
                            NSLog("Logged %@", tp.description())
                        }
                    }   // End of check owith Distance and dTime
                } // End of else
                // Ok now we may try to send the tp
                
                var doit = false;
                
                if let ltm = self.lastTimeSent {
                    if (tp.dtime.timeIntervalSince1970 - ltm.timeIntervalSince1970) > self.deltaSend {
                        doit = true;
                    }
                }
                else
                {
                    doit = true;
                }
                self.sendPoint(tp, procesa: doit)
                if doit {
                    self.lastTimeSent = Date()
                }
                //tp = nil
            }
        } // Fi del for en locations
        
        // [self updateBoundingBox]; //  Updatinf general data
        
        let lastArrayPoint = self.data.count;
        
        if self.hdl != nil {
            
            objc_sync_enter(self.hdl)
            
            if let ahdl = self.hdl{
                for i in self.lastPointWritten+1 ..< lastArrayPoint {
                    let pt = self.data[i]
                    
                    if let dat = pt.xmlText.data(using: String.Encoding.utf8){
                        ahdl.write(dat)
                    }
                    
                    
                }
                self.lastPointWritten = lastArrayPoint - 1
                
                // OK ara hem de eliminar els trackpoints
                /*
                if lastArrayPoint-1 > 1 {
                self.data.removeRange(1..<lastArrayPoint-1)
                self.lastPointWritten = 1
                }
                */
                
                // Fi de eliminar els points
            }
            objc_sync_exit(self.hdl)
        }
    }
    
    
    func addPoints(_ arr: [TGLTrackPoint])
    {
        var pt1 : TGLTrackPoint?
        //        var pt0 : TGLTrackPoint?
        
        if self.data.count > 0{
            //            pt0 = self.data[0]
            pt1 = self.data.last
        }
        else{
            self.totalAscent = 0.0
            self.totalDescent = 0.0
        }
        
        
        for pt in arr {
            
            if let ptl = pt1 {  // Compute acums
                let dh = pt.ele - ptl.ele
                
                if dh > 0.0{
                    self.totalAscent += dh
                }
                
                if dh < 0.0 {
                    self.totalDescent -= dh
                }
            }
            
            self.data.append(pt)
            pt1 = pt
            
            
            // Ok now we may try to send the tp
            
            var doit = false;
            
            if let ltm = self.lastTimeSent {
                if (pt.dtime.timeIntervalSince1970 - ltm.timeIntervalSince1970) > self.deltaSend {
                    doit = true;
                }
            }
            else
            {
                doit = true;
            }
            
            self.sendPoint(pt, procesa: doit)
            if doit {
                self.lastTimeSent = Date()
            }
            
        } // Fi del for en locations
        
        // [self updateBoundingBox]; //  Updatinf general data
        
        let lastArrayPoint = self.data.count;
        
        if self.hdl != nil {
            
            objc_sync_enter(self.hdl)
            
            if let ahdl = self.hdl{
                for i in self.lastPointWritten+1 ..< lastArrayPoint {
                    let pt = self.data[i]
                    
                    if let dat = pt.xmlText.data(using: String.Encoding.utf8){
                        ahdl.write(dat)
                    }
                }
                self.lastPointWritten = lastArrayPoint - 1
                
                // OK ara hem de eliminar els trackpoints
                /*
                if lastArrayPoint-1 > 1 {
                self.data.removeRange(1..<lastArrayPoint-1)
                self.lastPointWritten = 1
                }
                */
                
                // Fi de eliminar els points
            }
            objc_sync_exit(self.hdl)
        }
    }
    
    
    // MARK: - Utilities
    
    func getSlope(_ np : Int) -> Double{
        
        if self.data.count < 2 {    // Need a minimum of 2 points
            return 0.0
        }
        
        let last = self.data.count - 1
        var first = self.data.count - np
        
        if first < 0{
            first = 0
        }
        
        var deltay = 0.0
        
        if self.data[last].relativeEle != 0.0 || self.data[first].ele != 0.0{
            deltay = self.data[last].relativeEle - self.data[first].relativeEle
        } else {
            deltay = self.data[last].ele - self.data[first].ele
        }
        
        let deltax = self.data[last].distanciaOrigen - self.data[first].distanciaOrigen
        
        if deltax == 0{
            return 0.0
        }else {
            return deltay / deltax
        }
        
        
    }
    
    func getVAM(_ np : Int) -> Double{
        
        if self.data.count < 2 {    // Need a minimum of 2 points
            return 0.0
        }
        
        let last = self.data.count - 1
        var first = self.data.count - np
        
        if first < 0{
            first = 0
        }
        
        var deltay = 0.0
        
        if self.data[last].relativeEle != 0.0 || self.data[first].ele != 0.0{
            deltay = self.data[last].relativeEle - self.data[first].relativeEle
        } else {
            deltay = self.data[last].ele - self.data[first].ele
        }
        
        let deltax = self.data[last].dtime.timeIntervalSince(self.data[first].dtime as Date)

   
        
        if deltax == 0{
            return 0.0
        }else {
            return (deltay / deltax) * 3600.0   // Volem m/h
        }
        
        
    }

    
    func updateBoundingBox() -> ()
    {
        
        if self.data.count == 0
        {
            self.minLat = 0.0
            self.maxLat = 0.1
            self.minLon = 0.0
            self.maxLon = 0.1
            
            return;
        }
        
        var oldPt = self.data.first!
        var oldOldPt : TGLTrackPoint? = nil
        let zeroDate = oldPt.dtime
        
        oldPt.distanciaOrigen = 0.0
        
        self.minLat = oldPt.coordinate.latitude
        self.maxLat = oldPt.coordinate.latitude
        self.minLon = oldPt.coordinate.longitude
        self.maxLon = oldPt.coordinate.longitude
        
        var dist : CLLocationDistance = 0.0;
        
        var first = true
        for tpt in self.data {
            if !first {
                
                
                if tpt.coordinate.latitude > self.maxLat{
                    self.maxLat = tpt.coordinate.latitude
                }
                
                if tpt.coordinate.latitude < self.minLat{
                    self.minLat = tpt.coordinate.latitude
                }
                
                if tpt.coordinate.longitude > self.maxLon {
                    self.maxLon = tpt.coordinate.longitude
                }
                
                if tpt.coordinate.longitude < self.minLon{
                    self.minLon = tpt.coordinate.longitude
                }
                
                dist = dist + tpt.location.distance(from: oldPt.location)
                
                //if(tpt.distanciaOrigen < 0.0) // era per evitar modificar les dades exportades pero amb millors algoritmes no cals
                
                tpt.distanciaOrigen = dist;
                
                tpt.tempsOrigen = tpt.dtime.timeIntervalSince(zeroDate)
                
                if oldOldPt != nil
                {
                    oldPt.speed = (tpt.distanciaOrigen - oldOldPt!.distanciaOrigen)/(tpt.tempsOrigen - oldOldPt!.tempsOrigen)
                }
                
                oldOldPt = oldPt
                oldPt = tpt
            }
            else
            {
                first = false;
            }
            
        }
        
        // If there is data in self.laps we convert it to Waypoints excep lap
        // with value  = 0(start)
        
        if self.laps.count > 0{
            
            var iLap = 0;
            var t : TimeInterval = 0.0;
            
            for lp : Double in self.laps
            {
                if iLap != 0{
                    t = t + lp  // Sumem el temps del lap
                    
                    let ip = self.nearerTrackPointForTime(t)
                    
                    let tp = self.data[ip]
                    let wp = TMKWaypoint.newWaypointFromTrackPoint(_trackPoint: tp)
                    wp.title = "Lap \(iLap)"
                    wp.track = self;
                    wp.type = WaypointType.waypoint
                    
                    self.waypoints.append(wp)
                }
                
                iLap += 1
            }
            
            self.laps.removeAll(keepingCapacity: true)   // Clear data
        }
        
        
        // Now update waypoints so they have the distance and data of the nearer track point
        
        for tp : TMKWaypoint in self.waypoints
        {
            tp.buildNewData()
        }
        
        //self.waypoints.so sortUsingSelector:@selector(compareDistance:)];
        
        self.waypoints.sort { (p1 : TMKWaypoint, p2 : TMKWaypoint) -> Bool in
            return p1.distanciaOrigen <= p2.distanciaOrigen
        }
        
        // TODO: Construir funcions de acumulats
        
        /*
        
        self.totalAscent = [self ascentFromPoint:0 toPoint:self.data.count-1];
        self.totalDescent = [self descentFromPoint:0 toPoint:self.data.count-1];
        */
        
    }
    
    
    open func nearerTrackPointForTime(_ t : TimeInterval) -> (Int)
    {
        
        // Fem una busqueda binaria per trobar un punt
        // que sigui inferior o igual i el seguent
        
        var nmax = self.data.count
        var nmin = 0
        var ip : Int =  (nmin + nmax) / 2;
        
        while (nmax - nmin) > 1
        {
            ip =  (nmin + nmax) / 2;
            
            let tp = self.data[ip]
            
            if tp.tempsOrigen > t {
                nmax = ip
            }
            else
            {
                nmin = ip
            }
        }
        
        return ip
        
    }
    
    open func nearerTrackPointForLocation(_ loc : CLLocation) -> (Int){
        
        var ip = -1;
        var dist = CLLocationDistanceMax  // No hi ha cap lloc a la Terra tan lluny!!!
        
        for i in 0..<self.data.count {
            let tp = self.data[i]
            let lc = tp.distanceFromLocation(loc)
            
            if lc < dist {
                ip = i
                dist = lc
            }
        }
        
        return ip
    }
    
    open func imageWithWidth(_ wid:Double,  height:Double) -> UIImage {
        
        TMKImage.beginImageContextWithSize(CGSize(width: CGFloat(wid) , height: CGFloat(height)))
        
        var rect = CGRect(x: 0, y: 0, width: CGFloat(wid), height: CGFloat(height))   // Total rectangle
        
        var bz = UIBezierPath(rect: rect)
        
        UIColor.white.set()
        bz.fill()
        bz.stroke()
        
        rect = rect.insetBy(dx: 3.0, dy: 3.0);
        
        bz = UIBezierPath(rect:rect)
        bz.lineWidth = 2.0
        bz.stroke()
        
        
        
        let p0 = MKMapPointForCoordinate(CLLocationCoordinate2DMake(self.minLat, self.minLon))
        
        let p1 = MKMapPointForCoordinate(CLLocationCoordinate2DMake(self.maxLat, self.maxLon))
        
        // Get Midpoint
        
        
        let scalex : Double = fabs(wid * 0.9 / (p1.x - p0.x))  // 90 % de l'area
        let scaley : Double = fabs(height * 0.9 / (p1.y - p0.y))  // 90 % de l'area
        
        let scale : Double = scalex < scaley ? scalex : scaley
        
        let minx = p0.x < p1.x ? p0.x : p1.x
        let miny = p0.y < p1.y ? p0.y : p1.y
        
        // Compute midpoint
        
        let pm = MKMapPointMake((p0.x+p1.x)/2.0, (p0.y+p1.y)/2.0)
        let pmc = MKMapPointMake((pm.x-minx)*scale, (pm.y-miny)*scale)
        let offset = MKMapPointMake((wid/2.0)-pmc.x, (height/2.0)-pmc.y)
        
        bz  = UIBezierPath()
        
        var primer = true
        
        
        for pt : TGLTrackPoint in self.data {
            let p = MKMapPointForCoordinate(pt.coordinate)
            
            let x : CGFloat = CGFloat((p.x-minx) * scale + offset.x)
            let y : CGFloat = CGFloat((p.y-miny) * scale + offset.y)
            if primer
            {
                bz.move(to: CGPoint(x: x,y: y))
                primer = false
            }
            else{
                bz.addLine(to: CGPoint(x: x,y: y))
            }
            
        }
        
        bz.lineWidth = 5.0
        bz.lineJoinStyle = CGLineJoin.round
        UIColor.red.setStroke()
        bz.stroke()
        let img = UIGraphicsGetImageFromCurrentImageContext()
        TMKImage.endImageContext()
        
        
        //        let library = ALAssetsLibrary()
        //
        //        let status = ALAssetsLibrary.authorizationStatus()
        //
        //        if status != ALAuthorizationStatus.Authorized{
        //            NSLog("No autoritzat a accedir a les Fotos")
        //
        //        }
        //        else{
        //
        //            var done = false
        //            var iter = 0
        //
        //            var cgim = img.CGImage
        //
        //            library.writeImageToSavedPhotosAlbum(cgim, orientation: ALAssetOrientation.Down, completionBlock: { (url:NSURL!, err:NSError?) -> Void in
        //
        //                if let er = err {
        //                    NSLog("Error : %@ ", er)
        //                }else{
        //                    NSLog("All Done : %@ ", url)
        //                }
        //                done = true
        //            })
        //
        //            do {
        //                sleep(1)
        //                iter++
        //                NSLog("Iter %d", iter)
        //            }while !done && iter < 50
        //
        //        }
        
        
        return img!
        
    }
    
    func updateHR(_ results : [HKQuantitySample], force:Bool=false) -> Bool {
        
        // Load Healthkit Data
        
        
        if results.count == 0{
            return false
        }
        
        let dele = UIApplication.shared.delegate as! AppDelegate
        
        var hdata : HealthAuxiliar?
        
        if let hd = dele.healthData {
            hdata = hd
        }
        
        
        var somethingDone = false
        
        // Load HeartRate from HealthStore between the two dates
        
        let unit = HKUnit(from: "count/min")
        
        var oldTp : TGLTrackPoint?
        
        for tp in self.data {
            if tp.heartRate == 0.0 || force{
                let d = tp.dtime
                var s0 = results.first!
                if d.timeIntervalSince1970 < s0.startDate.timeIntervalSince1970 {
                    continue
                }
                
                var s1 = results.last!
                
                if d.timeIntervalSince1970 > s1.endDate.timeIntervalSince1970{
                    continue
                }
                for i in 1..<results.count {
                    
                    s1 = results[i]
                    
                    if s1.startDate.timeIntervalSince1970 >= d.timeIntervalSince1970{
                        
                        let v0 = s0.quantity.doubleValue(for: unit)
                        let v1 = s1.quantity.doubleValue(for: unit)
                        let deltav = v1 - v0
                        
                        let deltat = s1.startDate.timeIntervalSince(s0.startDate)
                        let x = d.timeIntervalSince1970 - s0.startDate.timeIntervalSince1970
                        
                        let hr = v0 + deltav / deltat * x
                        tp.heartRate = hr
                        tp.filteredHeartRate = hr
                        
                        // Compute calories. Get time from previous point
                        
                        if let tp0 = oldTp, let hd = hdata {
                            
                            let d = tp.dtime.timeIntervalSince(tp0.dtime as Date)
                            
                            let cal = hd.calories(hr, duracio: d)
                            
                            tp.calories = cal.total
                            tp.activeCalories = cal.activ
                            
                        }
                        
                        oldTp = tp
                        
                        
                        somethingDone = true
                        break;
                    }
                    else{
                        s0 = s1
                    }
                    
                }
            }
        }
        
        return somethingDone
        
    }
    
    //MARK: - Connection with server to register track
    
    func sendPoint(_ tp : TGLTrackPoint, procesa : Bool)
    {
        // Get the App Delegate
        
        let del : AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let tpJSON = tp.toJSON()
        
        del.pushPoint(tpJSON)
        if procesa {
            del.procesServerQueue(false)
        }
        
    }
    
    
    
    //MARK:  - NSXMLParserDelegate
    
    open func cleanBC(){
        if self.buildingChars.length > 0{
            let range = NSRange(location: 0, length: self.buildingChars.length)
            self.buildingChars.deleteCharacters(in: range)
        }
        
    }
    
    open func  parserDidStartDocument(_ parser: XMLParser) {
        self.data = Array()
        self.waypoints = Array()
        self.laps = Array()
        
        firstPoint = true
        self.filterHeightLevel = 2
        self.filterSpeedLevel = 5
        self.filterBpmLevel = 0
        
        self.wpt = false
        self.oldPoint = nil
        
        // Clean building chars
        
        self.cleanBC()
    }
    
    open func  parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        
        //NSLog(@"Starting %@", elementName);
        
        switch elementName
        {
            
            
        case "trkpt":
            
            wpt = false
            point  = TGLTrackPoint()
            
            if let pt = point {
                
                let sLat : NSString? = attributeDict["lat"] as NSString?
                let sLon : NSString? = attributeDict["lon"] as NSString?
                
                pt.coordinate = CLLocationCoordinate2DMake( sLat!.doubleValue, sLon!.doubleValue)
                pt.distanciaOrigen = -1.0
                
            }
            
        case "wpt":
            
            wpt = true
            point  = TGLTrackPoint()
            
            if let pt = point {
                
                let sLat : NSString? = attributeDict["lat"] as NSString?
                let sLon : NSString? = attributeDict["lon"] as NSString?
                
                pt.coordinate = CLLocationCoordinate2DMake( sLat!.doubleValue, sLon!.doubleValue)
                pt.distanciaOrigen = -1.0
                
            }
            
            
        default:
            buildingChars.deleteCharacters(in: NSMakeRange(0, buildingChars.length))
            
            
        }
    }
    
    
    open func parser(_ parser: XMLParser, foundCharacters string: String) {
        
        buildingChars.append(string)
        
    }
    
    open func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        var nt = 0
        
        if let pt = point {
            switch elementName {
                
            case "ele":
                pt.ele = buildingChars.doubleValue
                
            case "hdop":
                pt.hPrecision = buildingChars.doubleValue
                
            case "vdop":
                pt.vPrecision = buildingChars.doubleValue
                
            case "time":
                
                let dat : Date? = self.dateFormatter.date(from: buildingChars as String)
                
                if let d1 = dat {
                    pt.dtime = d1
                }
                
            case "color":
                // Set track Color
                if wpt
                {
                    
                }
                else
                {
                    
                    let rRed = NSRange(location: 0, length: 2)
                    let rGreen = NSRange(location: 2, length: 2)
                    let rBlue = NSRange(location: 4, length: 2)
                    
                    
                    let colorString = buildingChars
                    let sRed = colorString.substring(with: rRed)
                    let sGreen = colorString.substring(with: rGreen)
                    let sBlue = colorString.substring(with: rBlue)
                    
                    var iRed : UInt32 = 0
                    var iGreen : UInt32 = 0
                    var iBlue : UInt32 = 0
                    
                    let scanRed = Scanner(string:sRed)
                    scanRed.scanHexInt32(&iRed)
                    
                    let scanGreen = Scanner(string:sGreen)
                    scanGreen.scanHexInt32(&iGreen)
                    
                    let scanBlue = Scanner(string:sBlue)
                    scanBlue.scanHexInt32(&iBlue)
                    
                    
                    let red  = CGFloat(CGFloat(iRed) / CGFloat(255.0))
                    let green = CGFloat(CGFloat(iGreen) / CGFloat(255.0))
                    let blue = CGFloat(CGFloat(iBlue) / CGFloat(255.0))
                    
                    self.color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
                    
                }
                
            case "name":
                if wpt {
                    if let wp = point as? TMKWaypoint {
                        wp.title = String(buildingChars)
                    }
                }
                
            case "desc":
                if wpt {
                    if let wp = point as? TMKWaypoint {
                        wp.notes = String(buildingChars)
                    }
                }
                
            case "gpxdata:hr", "gpxtpx:hr":
                // Compute time Veure el significat. De moment string
                if let pt = point {
                    pt.heartRate = buildingChars.doubleValue
                    pt.filteredHeartRate = pt.heartRate
                }
                
            case "gpxdata:temp":
                if let pt = point {
                    // Compute time Veure el significat. De moment string
                    pt.temperatura = buildingChars.doubleValue
                    
                }
                
            case"gpxdata:distance":
                if let pt = point {
                    // Compute time Veure el significat. De moment string
                    let d : CLLocationDistance = buildingChars.doubleValue
                    if d != 0.0{
                        pt.distanciaOrigen = d
                    }
                }
                
            case "gpxdata:calories":
                if let pt = point {
                    // Compute time Veure el significat. De moment string
                    pt.calories = buildingChars.doubleValue
                    
                }

                
            case "gpxdata:activecalories":
                if let pt = point {
                    // Compute time Veure el significat. De moment string
                    pt.activeCalories = buildingChars.doubleValue
                    
                }

            case "elapsedTime":
                lapTime = Double(buildingChars.integerValue)
                
            case "lap":
                self.laps.append(lapTime)
                lapTime = 0.0
                
            case "tracesdata:activity":
                if let pt = point {
                    pt.activity = CMMotionActivity.activityFromString(String(buildingChars))
                }
                
            case "tracesdata:heading":
                if let pr = point {
                    pr.heading = buildingChars.doubleValue
                }
                
            case "tracesdata:distancePedometer":
                if let pr = point {
                    pr.distanciaPedometer = buildingChars.doubleValue
                }
                
                
            case "wpt" :
                if let wp : TMKWaypoint = point as? TMKWaypoint {
                    
                    wp.track = self;
                    wp.color = MKPinAnnotationColor.red
                    
                    if wp.title != "Start" && wp.title != "End"{
                        self.waypoints.append(wp)
                    }
                }
                
                point = nil;
                wpt = false
                
            case "trkpt":
                if let pt = point
                {
                    if firstPoint {
                        oldPoint = point
                    }
                    
                    
                    var d : Double = DISTANCE
                    var dt : Double = TEMPS
                    
                    // dtime sempre te valor. Encara que sigui dolent
                    
                    
                    if let op = oldPoint{
                        d = pt.location.distance(from: op.location)
                        
                        
                        if pt.dtime.timeIntervalSince1970 > op.dtime.timeIntervalSince1970{
                            dt = pt.dtime.timeIntervalSince(op.dtime as Date)
                        }
                    }
                    
                    
                    if firstPoint || d  >= DISTANCE || dt  >= TEMPS
                    {
                        
                        // check to see if speed is crazy (over 30 km/h
                        var speed = 0.0;
                        
                        if !firstPoint  {
                            if let op = oldPoint{
                                if pt.dtime != op.dtime{
                                    speed = d / pt.dtime.timeIntervalSince(op.dtime as Date)
                                }
                            }
                        }
                            
                        else{
                            speed = 2.0
                        }
                        
                        if firstPoint || speed <= 20.4 // 8.4 es 30 km/h - Hauriem de tenir l'activitat
                        {
                            pt.speed = 0.0;
                            pt.filteredEle = pt.ele;
                            self.data.append(pt)
                            oldPoint  = pt
                            firstPoint = false
                        }
                    }
                    point = nil
                }
                
            default:
                nt += 1
                
            }
        }
        
    }
    
    
    open func  parserDidEndDocument(_ parser: XMLParser) {
        point = nil
        buildingChars.deleteCharacters(in: NSRange(location: 0, length: buildingChars.length))
        oldPoint = nil
    }
    
    
    open func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // NSLog(@"Datos %@", self.data);
        
        let delegate = UIApplication.shared.delegate as! AppDelegate
        
        let msg = String(format:"Error en el parsing %@ linea %d columna %d",
            parseError.localizedDescription,
            parser.lineNumber,
            parser.columnNumber)
        
        let tit = "Error al parsejar dades"
        delegate.displayMessage(msg, withTitle:tit)
    }
    
    
    
    
}
