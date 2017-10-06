//
//  TGLTrackPoint.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 30/1/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit
import MapKit
import CoreMotion

open class TGLTrackPoint  {
    
    let PRECISION = 10.0;
    
    open var coordinate : CLLocationCoordinate2D = CLLocationCoordinate2DMake(0.0, 0.0)
    open var ele : Double = 0.0
    open var relativeEle : Double = 0.0
    open var filteredEle : Double = 0.0
    open var dtime : Date = Date()
    
    
    open var hPrecision : CLLocationAccuracy = -1.0  // Bad Point
    open var vPrecision : CLLocationAccuracy = -1.0  // Bad Point
    open var distanciaOrigen : CLLocationDistance = 0.0
    open var tempsOrigen : TimeInterval = 0.0
    open var speed : CLLocationSpeed = 0.0
    open var filteredSpeed : CLLocationSpeed = 0.0
    open var heading : CLLocationDirection = 0.0
    open var distanciaPedometer : Double = 0.0
    
    open var heartRate : Double = 0.0
    open var filteredHeartRate : Double = 0.0
    open var temperatura : Double = 0.0
    open var calories : Double = 0.0
    open var activeCalories : Double = 0.0
    
    open var activity : ActivityEnum = .unknown
    
    
    
    
    open var selected = false
    
    var otherFormatter : DateFormatter;
    
    // Returns position as a CLLocation instance
    
    public init()
    {

        self.otherFormatter = DateFormatter();
        self.otherFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        self.otherFormatter.timeZone = TimeZone(abbreviation: "UTC")
        self.otherFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'.000Z'"

    }
    
    // MARK: - Calculated properties
    
    
    open var activityDesc : String
    {        
        return CMMotionActivity.activityDescription(self.activity)
    }
    
    open var time : String
    {
        return self.otherFormatter.string(from: self.dtime);
    }
    open var location : CLLocation
    {
       return CLLocation.init(latitude: coordinate.latitude,longitude: coordinate.longitude);
    }

    open var tempsOrigenAsString :String
    {
        return TGLTrackPoint.stringFromTimeInterval(self.tempsOrigen);
    }
    
    open var xmlText : String
    {
        let str : NSMutableString = NSMutableString();
        str.appendFormat("<trkpt lat=\"%7.5f\" lon=\"%7.5f\">\n", self.coordinate.latitude, self.coordinate.longitude)
        
        let timeString :String = self.time.replacingOccurrences(of: " ",  with: "").replacingOccurrences(of: "\n",with: "").replacingOccurrences(of: "\r",with: "")
        
        str.appendFormat("<ele>%3.0f</ele>\n", self.ele)
        str.appendFormat("<time>\(timeString)</time>\n" as NSString)
        
        if self.hPrecision != -1
        {
            str.appendFormat("<hdop>%7.2f</hdop>\n", self.hPrecision)
        }
        
        if self.vPrecision != -1
        {
            str.appendFormat("<vdop>%7.2f</vdop>\n", self.vPrecision)
        }
        
        
        str.append("<extensions>\n")
        str.appendFormat("<gpxdata:hr>%4.2f</gpxdata:hr>\n", self.heartRate)
        str.appendFormat("<gpxdata:temp>%4.2f</gpxdata:temp>\n", self.temperatura)
        str.appendFormat("<gpxdata:distance>%8.2f</gpxdata:distance>\n", self.distanciaOrigen)
        if self.calories != 0.0 {
            str.appendFormat("<gpxdata:calories>%8.2f</gpxdata:calories>\n", self.calories)
        }
        if self.activeCalories != 0.0 {
            str.appendFormat("<gpxdata:activecalories>%8.2f</gpxdata:activecalories>\n", self.activeCalories)
        }

        str.appendFormat("<tracesdata:activity>%@</tracesdata:activity>\n", self.activityDesc)
        str.appendFormat("<tracesdata:heading>%8.2f</tracesdata:heading>\n", self.heading)
        str.appendFormat("<tracesdata:distancePedometer>%8.2f</tracesdata:distancePedometer>\n", self.distanciaPedometer)
        str.append("</extensions>\n")
        str.append("</trkpt>\n")
        
        return str as String;
    }
    
    // TODO : - Add UTM support creating a computed UTM coordinate
    
    //@property (nonatomic) UTMCoordinates utm



    // MARK: - Test and compare functions
    
    open func isEqualTo (_ pt : TGLTrackPoint?) -> (Bool)
    {
        if let pt0 = pt{
            return fabs(self.distanciaOrigen - pt0.distanciaOrigen) < PRECISION
        }
        else
        {
            return false;
        }
    }

    open func compareDistance (_ pt : TGLTrackPoint) -> (ComparisonResult)
    {
        if self.distanciaOrigen < pt.distanciaOrigen
        {
            return ComparisonResult.orderedAscending;
        }
        else if self.distanciaOrigen > pt.distanciaOrigen
        {
            return ComparisonResult.orderedDescending;
        }
        else
        {
            return ComparisonResult.orderedSame;
        }
        
    }

    // MARK: - Utilities functions
    
    open func distanceFrom ( _ pt : TGLTrackPoint) -> (CLLocationDistance)   // In Meters
    {
        return self.location.distance(from: pt.location);
    }
    
    open func distanceFromLocation (_ loc: CLLocation) -> (CLLocationDistance) // In Meters
    {
        return self.location.distance(from: loc);
    }
    
    
    func description() -> String
    {
    
        return NSString(format:"Lat %f Lon %f Ele %f Sigmah %f Sigmav %f hr %f",
            self.coordinate.latitude,
            self.coordinate.longitude,
            self.ele,
            self.hPrecision,
            self.vPrecision,
            self.heartRate) as String
    }
    
    func getUrl(_ server : String) -> URL? {
        
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd+HH:mm:ss"
            let sdate = fmt.string(from: self.dtime)
            
            let uuid = UIDevice.current.identifierForVendor
            let suuid = uuid!.uuidString
            
            let param = String(format: "%@?id=%@&date=%@&lat=%0.5f&lon=%0.5f&ele=%0.2f", server,suuid, sdate, self.coordinate.latitude, self.coordinate.longitude, self.ele)
        
            return URL(string: param)
    }
    
    func toJSON() -> NSDictionary {
        
        let tpj = NSMutableDictionary()
        tpj.setJSONPoint(trackPoint: self)
        return tpj
        
    }

    // MARK: -  Class utilities
    
    class func stringFromTimeInterval (_ interval: TimeInterval) -> (String){ // Veure de convertir-ho a type o
        let ti : Int = Int(interval)
        let seconds : Int  = ti % 60;
        let minutes : Int  = (ti / 60) % 60;
        let hours : Int = (ti / 3600);
        return "\(hours):\(minutes):\(seconds)"

    }
        
    
}
