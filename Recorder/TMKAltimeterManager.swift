//
//  TMKAltimeterManager.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 21/3/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit
import CoreMotion
import MapKit


class TMKAltimeterManager: NSObject, CLLocationManagerDelegate{
    
    
    //MARK: - Controllers and system
    
    var delegate : TMKAltimeterManagerDelegate?
    var locationManager : CLLocationManager? = CLLocationManager()
    var motionActivityManager : CMMotionActivityManager?
    var location : CLLocation?
    var altimeter : CMAltimeter?
    weak var hrMonitor : TMKHeartRateMonitor?
    var pedometer : CMPedometer?
    
    let precision : Double = 0.04*0.04      // Precisio de la diferencia d'alçades del altimetre al quadrat
    
    //MARK: - Arrays and queues for receiving and storing data
    
    var medidas : [TMKAltitudeData]
    var posiciones : [CLLocation]
    var distancias : [CMPedometerData]
    var altQueue : OperationQueue?
    var actQueue : OperationQueue
    
    //MARK : - State
    
    var updating : Bool = false
    var bootTime : TimeInterval = 0.0
    
    //MARK: - Tracking data
    
    var startTime : Date?                     // When we start tracking
    var startAltitude : Double  = 0.0           // First altitude data to add to all points from altimeter to get real altitude
    var lastPoint : TGLTrackPoint?              // Last point processed
    var lastLoc : CLLocation?                   // Last location received from GPS
    
    //MARK : - Kalman instant data
    
    var actualAltitude : TMKAltitudeData?   // Ultim valor de alçada usat per el Kalman - Relative
    var actualHeight = 0.0                  // Altura actual del Kalman calculada - Real
    var actualPrecission = 0.0              // Precisió actual de la alçada del Kalman
    var actualLocation : CLLocation?        // Posició actual
    var actualTime : TimeInterval = 0.0   // Timpestamp correspon a la actual***
    var actualActivity : CMMotionActivity?  // Actual Activity
    
    var inicialitzat = false                // Indica si ja hem processat algun punt i els actual tenen valor
    
    var deferringUpdates : Bool = false
    
    
    var ascentSpeed = 0.0       // En m/s
    var descentSpeed = 0.0       // En m/s
    
    //MARK: - Init
    
    override init(){
        debugLaunch("TMKAltimeterManager init enter")
        
        medidas = [TMKAltitudeData]()
        posiciones = [CLLocation]()
        actQueue = OperationQueue()
        distancias = [CMPedometerData]()
        super.init()
        bootTime = self.getBootTime()
        actQueue.maxConcurrentOperationCount = 1; // Processem les dades ens serie
        
        if CMPedometer.isDistanceAvailable(){
            self.pedometer = CMPedometer()
        }
        
        if CMMotionActivityManager.isActivityAvailable(){
            motionActivityManager = CMMotionActivityManager();
            
            motionActivityManager?.startActivityUpdates(to: self.actQueue, withHandler: { (acts : CMMotionActivity?) -> Void in
                
                
                if let act = acts {
                    if act.unknown {
                        self.actualActivity = act
                        NSLog("Activity %@", act)
                        if let dele = self.delegate, let act = self.actualActivity{
                            dele.updateActivity(act)
                        }
                    }
                }
            })
        }
        
        if let locm = self.locationManager {
            debugLaunch("Configuring LocationManager")
            
            
            locm.delegate = self
            locm.activityType = CLActivityType.fitness
            locm.desiredAccuracy = kCLLocationAccuracyBest
            locm.distanceFilter = kCLDistanceFilterNone
            
            if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.notDetermined
                || CLLocationManager.authorizationStatus() == CLAuthorizationStatus.denied {
                    DispatchQueue.main.async(execute: { () -> Void in
                        
                        locm.requestAlwaysAuthorization()
                    })
                    
            }
            
            debugLaunch("End Configuring LocationManager")
            
        }
        debugLaunch("TMKAltimeterManager init exit")
    }
    
    
    //MARK: - Utilities
    
    func getBootTime() -> TimeInterval
    {
        
        //NSTimeInterval uptime = [[NSProcessInfo processInfo] systemUptime];
        return Date().timeIntervalSince1970-ProcessInfo.processInfo.systemUptime
    }
    
    func computeAscentDescentRate(_ ti : TimeInterval){
        
        let n = self.medidas.count
        var ascent = 0.0
        var descent = 0.0
        var tascent = 0.0
        var tdescent = 0.0
       
        
        let d = Date().timeIntervalSince1970
        
        for i in ((0 + 1)...n-1).reversed() {
            let m = self.medidas[i]
            if m.timestamp < d - ti {
             break
            }
            else{
                
                let m0 = self.medidas[i-1]
                let dt = m.timestamp - m0.timestamp
                
                if m.relativeAltitude > m0.relativeAltitude{    // Climb
                    ascent += (m.relativeAltitude-m0.relativeAltitude)
                    tascent += dt
                    
                }
                else if m.relativeAltitude < m0.relativeAltitude{       // Descent
                    descent += (m0.relativeAltitude-m.relativeAltitude)
                    tdescent += dt
                }
                
            }
        }
        
        // compute speeds
        
        if tascent > 0.0 {
            self.ascentSpeed = ascent / tascent
        }
        else{
            self.ascentSpeed = 0.0
        }
        
        if tdescent > 0.0 {
            self.descentSpeed = descent / tdescent
        }
        else{
            self.descentSpeed = 0.0
        }
        
        
    }
    
    // MARK: Operations
    
    func startUpdating(){
        
        if self.updating {
            return
        }
        
        if self.altQueue == nil{
            self.altQueue = OperationQueue()
            self.altQueue!.maxConcurrentOperationCount = 1
        }
        
        if CMAltimeter.isRelativeAltitudeAvailable(){
            if self.altimeter == nil{
                self.altimeter = CMAltimeter()
            }
        }
        
        //  Set start time
        
        self.startTime = Date()                   // When we start tracking
        
        // Clear instant data
        
        self.lastLoc = nil
        self.actualLocation = nil
        self.actualHeight = 0.0
        self.actualAltitude = nil
        self.actualActivity = nil
        self.lastPoint = nil
        self.startAltitude = 0.0
        
        // init state variables
        
        self.inicialitzat = false
        self.deferringUpdates = false
        
        // Clear Buffers
        
        self.medidas.removeAll(keepingCapacity: false)
        self.posiciones.removeAll(keepingCapacity: false)
        self.distancias.removeAll(keepingCapacity: false)
        
        // Start reading altimeter data
        
        if let altm = self.altimeter{
            self.updating = true
            
            altm.startRelativeAltitudeUpdates(to: self.altQueue!,
                withHandler: { (alts : CMAltitudeData?, error : Error?) -> Void in
                    
                    if let alt = alts {
                        let dat = TMKAltitudeData(altitude: alt.relativeAltitude.doubleValue, pressure: alt.pressure.doubleValue, timestamp: alt.timestamp+self.bootTime)
                        
                        
                        objc_sync_enter(self)
                        self.medidas.append(dat)
                        objc_sync_exit(self)
                        
                        if self.medidas.count > 1{
                            self.computeAscentDescentRate(60.0)
                        }
                    }
            })
        }
        
        
        
        
        
        
        // Start updating pedometer data
        
        if let p = self.pedometer{
            
            p.startUpdates(from: self.startTime!, withHandler: { (datas:CMPedometerData?, err:Error?) -> Void in
                
                if let data = datas {
                    self.distancias.append(data)
                }
            })
        }
        
        // Start reading position data
        
        if let locm = self.locationManager {
            if #available(iOS 9.0, *) {
                locm.allowsBackgroundLocationUpdates = true
            }
            locm.startUpdatingLocation() // Haurem de modificar posteriorment
            debugLaunch("LocationManager started")
            
        }
        
        
        
    }
    
    
    func pauseUpdating()
    {
        if let locm = self.locationManager{
            locm.stopUpdatingLocation()
        }
    }
    
    func resumeUpdating()
    {
        if let locm = self.locationManager{
            locm.startUpdatingLocation()
        }
    }
    
    func stopUpdating()
    {
        if !self.updating {
            return
        }
        
        if let p = self.pedometer{
            p.stopUpdates()
        }
        
        if let locm = self.locationManager{
            locm.stopUpdatingLocation() // Haurem de modificar posteriorment
            if #available(iOS 9.0, *) {
                locm.allowsBackgroundLocationUpdates = false
            }

            debugLaunch("LocationManager stopped")
            
        }
        
        if let altm = self.altimeter{
            altm.stopRelativeAltitudeUpdates()
            debugLaunch("Altimeter stopped")
            
        }
        
        self.medidas = Array()
        //self.posiciones = nil;
        self.updating = false
        
        
    }
    
    //MARK: - Accessing data
    
    func distanciaAt(_ tim: Date) -> Double{
        
        if self.distancias.count == 0{
            return -1.0
        }
        
        if  let dat = self.distancias.first {
            if dat.endDate.timeIntervalSince1970 > tim.timeIntervalSince1970 {  // Buaaa no tenim dades
                return -1.0
            }
        }
        
        var oldData : CMPedometerData?
        
        for dat in self.distancias {
            
            if dat.endDate.timeIntervalSince1970 > tim.timeIntervalSince1970 {
                
                // Calculem el punt mitg
                
                
                if let od = oldData {
                    
                    let dt = dat.endDate.timeIntervalSince1970 - od.endDate.timeIntervalSince1970
                    
                    if dt == 0 {
                        return Double(dat.distance!)
                    }
                    else
                    {
                        let dx = tim.timeIntervalSince1970-od.endDate.timeIntervalSince1970
                        let dd = dat.distance!.doubleValue - od.distance!.doubleValue
                        let d = od.distance!.doubleValue + dd/dt*dx
                        
                        return d
                    }
                }
                else
                {
                    return Double(dat.distance!)
                }
                
            }
            else
            {
                oldData = dat
            }
            
        }
        
        if let l = self.distancias.last {
            return l.distance!.doubleValue
        }
        return -1.0
    }
    
    func beforeTimestamp(_ time: TimeInterval) -> Int
    {
        
        var before = -1
        var n  = 0
        
        //        if self.medidas == nil{
        //           return -1
        //       }
        
        
        objc_sync_enter(self)
        n = self.medidas.count
        
        if n != 0 {
            for i in 0...n-1 {
                let dat = self.medidas[i]
                
                if dat.timestamp <= time{
                    before = i
                }
                else
                {
                    break
                }
            }
        }
        objc_sync_exit(self)
        
        return before
    }
    
    func afterTimestamp(_ time : TimeInterval) -> Int
    {
        
        var after = -1
        var n = 0
        
        //if(self.medidas == nil)
        //return -1;
        
        
        objc_sync_enter(self)
        n = self.medidas.count
        
        
        if n != 0 {
            
            for i in 0...n-1{
                let dat = self.medidas[i]
                
                if dat.timestamp >= time
                {
                    after = i;
                    break;
                    
                }
            }
        }
        
        objc_sync_exit(self)
        
        
        return after
        
    }
    
    
    func altitudeDataForTimestamp(_ time : TimeInterval) -> TMKAltitudeData?
    {
        
        var before : TMKAltitudeData?
        var after : TMKAltitudeData?
        
        objc_sync_enter(self)
        
        // Check if medidas has data
        
        if self.medidas.count == 0{
            objc_sync_exit(self)
            return nil
        }
        
        // Lookup a measure before and another after
        
        let n = self.medidas.count
        var stop = false
        
        var i = 0
        
        while i < n && !stop {
            let dat : TMKAltitudeData = self.medidas[i]
            if dat.timestamp <= time {
                before = dat;
            }
            else{
                stop = true
            }
            i += 1
            
        }
        
        
        stop = false
        
        i = 0
        
        while i < n && !stop {
            let dat : TMKAltitudeData = self.medidas[i]
            if dat.timestamp >= time {
                after = dat;
                stop = true
            }
            
            i += 1
            
        }
        
        objc_sync_exit(self)
        
        // Cas 1 before = nil, after = nil - No tinc dades
        
        if before == nil && after == nil {
            return nil
        }
        
        // Cas 2 before = nil, after <> nil - Tan sols tinc una entrada posterior.
        // Si el temps es a prop (menys de 5 s) retornem la entrada
        
        if before == nil{
            
            if let af = after {
                if fabs(af.timestamp-time) < 5.0{
                    return after
                }
            }
        }
        
        // Cas 3 after = nil before <> nil - Tinc una entrada anterior
        
        if after == nil {
            if let bef = before {
                if fabs(bef.timestamp - time) < 5.0{
                    return before
                }
            }
        }
        
        // Cas 4 before <> nil && after <> nil
        
        if let bef : TMKAltitudeData = before  {
            if let  aft : TMKAltitudeData  = after{
                
                if bef.timestamp == aft.timestamp {
                    return after
                }
                    
                else if fabs(bef.timestamp - time) < 0.01{
                    return before
                }
                    
                else if fabs(aft.timestamp - time) < 0.01{
                    return after
                }
                    
                else    // Interpolem
                {
                    let deltat = aft.timestamp - bef.timestamp
                    let deltah = aft.relativeAltitude - bef.relativeAltitude
                    let deltap = aft.pressure - bef.pressure
                    
                    let x = time-bef.timestamp
                    
                    let h = bef.relativeAltitude + (deltah / deltat * x);
                    let p = bef.pressure + (deltap / deltat * x)
                    
                    let res = TMKAltitudeData(altitude:h, pressure:p, timestamp:time)
                    return res
                    
                }
                
            }
        }
        return nil
    }
    
    
    func altitudeDifferenceFromTimestamp(_ fromTime : TimeInterval,  ToTimestamp toTime:TimeInterval) -> Double?
    {
        
        let from  = self.altitudeDataForTimestamp(fromTime)
        
        let tos = self.altitudeDataForTimestamp(toTime)
        
        if let fr = from   {
            if let ts = tos {
                return ts.relativeAltitude - fr.relativeAltitude
            }
        }
            
        else if from == nil {
            if let ts = tos {
                return ts.relativeAltitude
            }
        }
            
        else if tos == nil {
            if let fr = from {
                return -fr.relativeAltitude
            }
        }
        
        return nil
    }
    
    //MARK: - Processing Data
    
    func filterAltura()
    {
        var newLocs = [CLLocation]()
        
        
        // Si no tenim dades no tenim res a fer.
        
        if self.posiciones.count == 0 {
            return
        }
        
        // Si es el primer punt hem de inicialitzar els valors i el retornem directament
        
        newLocs = [CLLocation]()     // Nou buffer de sortida
        
        if !self.inicialitzat {
            self.actualLocation = self.posiciones[0]
            if let loc = self.actualLocation{
                self.actualHeight = loc.altitude
                self.actualPrecission = loc.verticalAccuracy*loc.verticalAccuracy   // Sigma2
                self.actualTime = loc.timestamp.timeIntervalSince1970
                self.actualAltitude = self.altitudeDataForTimestamp(self.actualTime) // Mentre no tinguem un valor no nil no podrem filtrar
                
                objc_sync_enter(self)
                self.posiciones.remove(at: 0)
                newLocs.append(loc)
                objc_sync_exit(self)
                self.inicialitzat = true
            }
        }
        
        
        // Perfect, ara hem de anar processant els punts que van venint
        // Fins que trobem un que NO tingui alçada (vol dir que no tenim alçada)
        // per un moment igual o posterior al del punt;
        
        
        
        while self.posiciones.count > 0
        {
            // pt es el nou punt. Fem servir les nostres funcions per calcular quan ha pujat segons barometre
            
            let pt = self.posiciones[0]
            
            let before = self.beforeTimestamp(pt.timestamp.timeIntervalSince1970)
            let after =  self.afterTimestamp(pt.timestamp.timeIntervalSince1970)
            
            if before == -1{     // En aquest cas el passem i no podem fer res de res doncs no tenim dades de alçada
                
                self.actualLocation = pt
                self.actualHeight = pt.altitude
                self.actualPrecission = pt.verticalAccuracy*pt.verticalAccuracy  // Sigma2
                self.actualTime = pt.timestamp.timeIntervalSince1970
                
                objc_sync_enter(self)
                self.posiciones.remove(at: 0)
                newLocs.append(pt)
                objc_sync_exit(self)
                
            }  // End before == -1
                
            else if after == -1 { // Encara no tenim dades de alçada. Esperem
                
                if fabs(pt.timestamp.timeIntervalSince1970 - Date().timeIntervalSince1970) < 20.0 {   // Esperem un maxim de 20 s
                    break
                }
                else             // Estem esperant massa. Potser el barometre no funciona!!!
                {
                    self.actualLocation = pt
                    self.actualHeight = pt.altitude
                    self.actualPrecission = pt.verticalAccuracy*pt.verticalAccuracy  // Sigma2
                    self.actualTime = pt.timestamp.timeIntervalSince1970
                    
                    objc_sync_enter(self)
                    self.posiciones.remove(at: 0)
                    newLocs.append(pt)
                    objc_sync_exit(self)
                }
            }   // End after == -1
            else
            {
                
                
                let beforeData = self.medidas[before]
                let afterData = self.medidas[after]
                
                let deltat = afterData.timestamp - beforeData.timestamp
                let deltah = afterData.relativeAltitude - beforeData.relativeAltitude
                let deltap = afterData.pressure - beforeData.pressure
                
                let x = pt.timestamp.timeIntervalSince1970-beforeData.timestamp;
                
                var hpt : Double = 0.0
                var ppt : Double = 0.0
                if fabs(deltat) < 0.01 || fabs(x) < 0.01 {// ELs dos punts son iguals i corresponen al valor que volem
                    
                    hpt = beforeData.relativeAltitude
                    ppt = beforeData.pressure
                }
                else{
                    hpt = beforeData.relativeAltitude + (deltah / deltat * x)
                    ppt = beforeData.pressure  + (deltap / deltat * x)
                }
                
                
                
                var deltaN : Double?
                
                if let actAlt = self.actualAltitude{
                    let delta = hpt - actAlt.relativeAltitude
                    deltaN = delta
                }
                else
                {
                    deltaN =  nil // De moment encara no podem fer servir aquesta dada. Fins el proper punt
                }
                
                
                // Ara calculem la nova altitut i el nou error en el moment de la nova mesura (Predict)
                
                var newHeight = self.actualHeight
                var newPrecission = self.actualPrecission
                let mPrecission = pt.verticalAccuracy*pt.verticalAccuracy
                
                // Inicialitcem h, sigma2 a les dades del GPS
                
                var h = pt.altitude
                var sigma2 = mPrecission
                
                if let delta = deltaN {  // Si tenim informaciò del altimetre processem les dades
                    
                    // Expected new altitude
                    
                    newHeight += delta
                    newPrecission += self.precision
                    
                    // I ara apliquem la convolució amb la nova mesura
                    
                    h = (newHeight * mPrecission + pt.altitude * newPrecission)/(newPrecission + mPrecission)    // h bona?
                    sigma2 = 1/((1.0/mPrecission) + (1.0/newPrecission))
                    
                    if GlobalConstants.debug{
                        NSLog("Calculant nova sigma a partir de %f i %f = %f", sqrt(mPrecission), sqrt(newPrecission), sqrt(sigma2))
                    }
                }
                
                
                // Actualitzem el punt
                
                let newLocation = CLLocation(coordinate: pt.coordinate, altitude: h, horizontalAccuracy: pt.horizontalAccuracy, verticalAccuracy: sqrt(sigma2), course: pt.course, speed: pt.speed, timestamp: pt.timestamp)
                
                objc_sync_enter(self)
                self.posiciones.remove(at: 0)
                newLocs.append(newLocation)
                objc_sync_exit(self)
                
                
                // Shift dels punts
                
                
                if GlobalConstants.debug{
                    NSLog("Filtrat h de %f +/- %f a %f +/- %f", pt.altitude, pt.verticalAccuracy, newLocation.altitude, newLocation.verticalAccuracy)
                }
                
                self.actualLocation = newLocation
                self.actualAltitude = TMKAltitudeData(altitude: hpt, pressure: ppt, timestamp: pt.timestamp.timeIntervalSince1970)
                self.actualHeight = h
                self.actualPrecission = sigma2
                self.actualTime = pt.timestamp.timeIntervalSince1970
                
                // Podem esborrar les mesures abans de before per anar mes rapids
                
                if(before > 0)
                {
                    
                    objc_sync_enter(self)
                    var items = self.medidas.count
                    
                    if before < items{
                        items = before
                    }
                    self.medidas.removeSubrange(0..<items)
                    objc_sync_exit(self)
                    
                }
            }   // End of else general
        }   // End of while
        
        
        
        // Call our delegate
        if newLocs.count > 0{
            if let dele = self.delegate {
                if let mgr = self.locationManager {
                    dele.locationManager(mgr, didUpdateLocations:newLocs)
                    
                }
            }
        }
    }
    
    // processData es similar a filterAltura amb la diferència que genera [TGLTrackPoint] i
    // crida la funció corresponent del delegate.
    //
    //  Incorpora al TGLTrackPoint informació adicional que pot venir del Pedometer o de un altre sistema
    //
    //  Per la resta fa servir el mateix sistema que fa el filterAltura
    
    func processData()
    {
        var newLocs = [TGLTrackPoint]()
        
        newLocs.removeAll(keepingCapacity: false)
        
        // Si no tenim dades no tenim res a fer.
        
        if self.posiciones.count == 0 {
            return
        }
        
        // Si es el primer punt hem de inicialitzar els valors i el retornem directament
        
        if !self.inicialitzat {
            self.actualLocation = self.posiciones[0]
            if let loc = self.actualLocation{
                self.actualHeight = loc.altitude
                self.actualPrecission = loc.verticalAccuracy*loc.verticalAccuracy   // Sigma2
                self.actualTime = loc.timestamp.timeIntervalSince1970
                self.actualAltitude = self.altitudeDataForTimestamp(self.actualTime) // Mentre no tinguem un valor no nil no podrem filtrar
                
                let  ptx = TGLTrackPoint()
                
                ptx.coordinate = loc.coordinate
                ptx.ele = loc.altitude
                ptx.filteredEle = loc.altitude
                ptx.dtime = loc.timestamp
                ptx.hPrecision = loc.horizontalAccuracy
                ptx.vPrecision = loc.verticalAccuracy
                ptx.distanciaOrigen = 0.0
                ptx.distanciaPedometer = 0.0
                ptx.heading = loc.course
                ptx.speed = loc.speed
                                
                if let hrm = self.hrMonitor{
                    ptx.heartRate = Double(hrm.hr)
                }
                else
                {
                    ptx.heartRate = 0.0
                }
                ptx.filteredHeartRate = ptx.heartRate
                ptx.temperatura = 0.0
                
                if let act = self.actualActivity {
                    ptx.activity = act.activEnum()
                }else{
                    ptx.activity = ActivityEnum.unknown
                }
                
                objc_sync_enter(self)
                self.posiciones.remove(at: 0)
                newLocs.append(ptx)
                self.lastPoint = ptx;
                objc_sync_exit(self)
                self.inicialitzat = true
            }
        }
        
        
        // Perfect, ara hem de anar processant els punts que van venint
        // Fins que trobem un que NO tingui alçada (vol dir que no tenim alçada)
        // per un moment igual o posterior al del punt;
        
        
        
        while self.posiciones.count > 0
        {
            // pt es el nou punt. Fem servir les nostres funcions per calcular quan ha pujat segons barometre
            
            let loc = self.posiciones[0]
            
            let before = self.beforeTimestamp(loc.timestamp.timeIntervalSince1970)
            let after =  self.afterTimestamp(loc.timestamp.timeIntervalSince1970)
            
            if before == -1{     // En aquest cas el passem i no podem fer res de res doncs no tenim dades de alçada
                
                self.actualLocation = loc
                self.actualHeight = loc.altitude
                self.actualPrecission = loc.verticalAccuracy*loc.verticalAccuracy  // Sigma2
                self.actualTime = loc.timestamp.timeIntervalSince1970
                
                
                let ptx : TGLTrackPoint = TGLTrackPoint()
                
                ptx.coordinate = loc.coordinate
                ptx.ele = loc.altitude
                ptx.filteredEle = loc.altitude
                ptx.dtime = loc.timestamp
                ptx.hPrecision = loc.horizontalAccuracy
                ptx.vPrecision = loc.verticalAccuracy
                
                if let lp = self.lastPoint {
                    ptx.distanciaOrigen = lp.distanciaOrigen + loc.distance(from: lp.location)
                }
                else{
                    ptx.distanciaOrigen = 0.0
                }
                ptx.heading = loc.course
                ptx.speed = loc.speed
                ptx.distanciaPedometer = self.distanciaAt(loc.timestamp)
                
                if let hrm = self.hrMonitor{
                    ptx.heartRate = Double(hrm.hr)
                }
                else
                {
                    ptx.heartRate = 0.0
                }
                ptx.filteredHeartRate = ptx.heartRate
                ptx.temperatura = 0.0
                
                if let act = self.actualActivity {
                    ptx.activity = act.activEnum()
                }else{
                    ptx.activity = ActivityEnum.unknown
                }
                
                
                objc_sync_enter(self)
                self.posiciones.remove(at: 0)
                newLocs.append(ptx)
                self.lastPoint = ptx
                objc_sync_exit(self)
                
            }  // End before == -1
                
            else if after == -1 { // Encara no tenim dades de alçada. Esperem
                
                if fabs(loc.timestamp.timeIntervalSince1970 - Date().timeIntervalSince1970) < 20.0 {   // Esperem un maxim de 20 s
                    break
                }
                else             // Estem esperant massa. Potser el barometre no funciona!!!
                {
                    self.actualLocation = loc
                    self.actualHeight = loc.altitude
                    self.actualPrecission = loc.verticalAccuracy*loc.verticalAccuracy  // Sigma2
                    self.actualTime = loc.timestamp.timeIntervalSince1970
                    
                    
                    let ptx : TGLTrackPoint = TGLTrackPoint()
                    
                    ptx.coordinate = loc.coordinate
                    ptx.ele = loc.altitude
                    ptx.relativeEle = self.medidas[before].relativeAltitude
                    ptx.filteredEle = loc.altitude
                    ptx.dtime = loc.timestamp
                    ptx.hPrecision = loc.horizontalAccuracy
                    ptx.vPrecision = loc.verticalAccuracy
                    if let lp = self.lastPoint {
                        ptx.distanciaOrigen = lp.distanciaOrigen + loc.distance(from: lp.location)
                    }
                    else{
                        ptx.distanciaOrigen = 0.0
                    }
                    ptx.heading = loc.course
                    ptx.speed = loc.speed
                    ptx.distanciaPedometer = self.distanciaAt(loc.timestamp)
                    
                    if let hrm = self.hrMonitor{
                        ptx.heartRate = Double(hrm.hr)
                    }
                    else
                    {
                        ptx.heartRate = 0.0
                    }
                    ptx.filteredHeartRate = ptx.heartRate
                    ptx.temperatura = 0.0
                    
                    if let act = self.actualActivity {
                        ptx.activity = act.activEnum()
                    }else{
                        ptx.activity = ActivityEnum.unknown
                    }
                    
                    
                    objc_sync_enter(self)
                    self.posiciones.remove(at: 0)
                    newLocs.append(ptx)
                    self.lastPoint = ptx
                    objc_sync_exit(self)
                }
            }   // End after == -1
            else
            {
                
                
                let beforeData = self.medidas[before]
                let afterData = self.medidas[after]
                
                let deltat = afterData.timestamp - beforeData.timestamp
                let deltah = afterData.relativeAltitude - beforeData.relativeAltitude
                let deltap = afterData.pressure - beforeData.pressure
                
                let x = loc.timestamp.timeIntervalSince1970-beforeData.timestamp;
                
                var hpt : Double = 0.0
                var ppt : Double = 0.0
                if fabs(deltat) < 0.01 || fabs(x) < 0.01 {// ELs dos punts son iguals i corresponen al valor que volem
                    
                    hpt = beforeData.relativeAltitude
                    ppt = beforeData.pressure
                }
                else{
                    hpt = beforeData.relativeAltitude + (deltah / deltat * x)
                    ppt = beforeData.pressure  + (deltap / deltat * x)
                }
                
                
                
                var deltaN : Double?
                
                if let actAlt = self.actualAltitude{
                    let delta = hpt - actAlt.relativeAltitude
                    deltaN = delta
                }
                else
                {
                    deltaN =  nil // De moment encara no podem fer servir aquesta dada. Fins el proper punt
                }
                
                
                // Ara calculem la nova altitut i el nou error en el moment de la nova mesura (Predict)
                
                var newHeight = self.actualHeight
                var newPrecission = self.actualPrecission
                let mPrecission = loc.verticalAccuracy*loc.verticalAccuracy
                
                // Inicialitcem h, sigma2 a les dades del GPS
                
                var h = loc.altitude
                var sigma2 = mPrecission
                
                if let delta = deltaN {  // Si tenim informaciò del altimetre processem les dades
                    
                    // Expected new altitude
                    
                    newHeight += delta
                    newPrecission += self.precision
                    
                    // I ara apliquem la convolució amb la nova mesura
                    
                    h = (newHeight * mPrecission + loc.altitude * newPrecission)/(newPrecission + mPrecission)    // h bona?
                    sigma2 = 1/((1.0/mPrecission) + (1.0/newPrecission))
                    
                    if GlobalConstants.debug{
                        NSLog("Calculant nova sigma a partir de %f i %f = %f", sqrt(mPrecission), sqrt(newPrecission), sqrt(sigma2))
                    }
                }
                
                
                // Actualitzem el punt
                
                let newLocation = CLLocation(coordinate: loc.coordinate, altitude: h, horizontalAccuracy: loc.horizontalAccuracy, verticalAccuracy: sqrt(sigma2), course: loc.course, speed: loc.speed, timestamp: loc.timestamp)
                
                
                let ptx : TGLTrackPoint = TGLTrackPoint()
                
                ptx.coordinate = loc.coordinate
                ptx.ele = h
                ptx.filteredEle = h
                ptx.relativeEle = hpt
                ptx.dtime = loc.timestamp
                ptx.hPrecision = loc.horizontalAccuracy
                ptx.vPrecision = sqrt(sigma2)
                ptx.heading = loc.course
                ptx.speed = loc.speed
                if let lp = self.lastPoint {
                    ptx.distanciaOrigen = lp.distanciaOrigen + loc.distance(from: lp.location)
                }
                else{
                    ptx.distanciaOrigen = 0.0
                }
                ptx.distanciaPedometer = self.distanciaAt(loc.timestamp)
                
                if let hrm = self.hrMonitor{
                    ptx.heartRate = Double(hrm.hr)
                }
                else
                {
                    ptx.heartRate = 0.0
                }
                ptx.filteredHeartRate = ptx.heartRate
                ptx.temperatura = 0.0
                
                if let act = self.actualActivity {
                    ptx.activity = act.activEnum()
                }else{
                    ptx.activity = ActivityEnum.unknown
                }
                
                
                objc_sync_enter(self)
                self.posiciones.remove(at: 0)
                newLocs.append(ptx)
                self.lastPoint = ptx
                objc_sync_exit(self)
                
                
                // Shift dels punts
                
                
                if GlobalConstants.debug{
                    NSLog("Filtrat h de %f +/- %f a %f +/- %f", loc.altitude, loc.verticalAccuracy, ptx.ele, ptx.vPrecision)
                }
                
                self.actualLocation = newLocation
                self.actualAltitude = TMKAltitudeData(altitude: hpt, pressure: ppt, timestamp: loc.timestamp.timeIntervalSince1970)
                self.actualHeight = h
                self.actualPrecission = sigma2
                self.actualTime = loc.timestamp.timeIntervalSince1970
                
                // Podem esborrar les mesures abans de before per anar mes rapids
                
                if(before > 0)
                {
                    
                    objc_sync_enter(self)
                    var items = self.medidas.count
                    
                    if before < items{
                        items = before
                    }
                    self.medidas.removeSubrange(0..<items)
                    objc_sync_exit(self)
                    
                }
            }   // End of else general
        }   // End of while
        
        
        
        // Call our delegate
        if newLocs.count > 0{
            if let dele = self.delegate {
                dele.updateTrackPoints(newLocs)
            }
        }
    }
    
    func stopMonitoringForRegion(_ region:CLRegion)
    {
        if let mgr = self.locationManager {
            mgr.stopMonitoring(for: region)
        }
    }
    
    func startMonitoringForRegion(_ region:CLRegion)
    {
        if let mgr = self.locationManager {
            mgr.startMonitoring(for: region)
        }
    }
    
    
    //MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus){
        //TODO: Add check for method existence
        // dele.locationManager(manager, didChangeAuthorizationStatus:status )
        
        if GlobalConstants.debug {
            NSLog("Location Manager auth status changed")
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation])
    {
        debugLaunch("LocationManager received locations")
        
        // Check if we have the speed and publish it
        
        let lastloc = locations.last
        
        if let sp = lastloc?.speed, let del = self.delegate{
            del.updateSpeed(sp)
        }
        
        // dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
        objc_sync_enter(self)
        
        for loc : CLLocation in locations {
            
            
            if loc.horizontalAccuracy <= 50.0{  // Other data is really bad bad bad. probably GPS not fixes
                
                if let llc = self.lastLoc{
                    if llc.distance(from: loc) >= 5.0{       // one point every 10 meters. Not less
                        self.posiciones.append(loc)
                        self.lastLoc = loc
                    }
                }
                else
                {
                    self.posiciones.append(loc)
                    self.lastLoc = loc
                }
            }
        }
        objc_sync_exit(self)
        
        //self.filterAltura()
        if self.posiciones.count > 0{
            self.processData()
        }
        //})
        
        if !self.deferringUpdates  {
            let distance : CLLocationDistance =  1000.0 // Update every km
            let time : TimeInterval = 60.0 // Or every 1'
            
            manager.allowDeferredLocationUpdates(untilTraveled: distance,  timeout:time)
            self.deferringUpdates = true
            
        }
    }
    
    
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        
        self.deferringUpdates = false
    }
    
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    }
    
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    }
    
    
    
    
}
