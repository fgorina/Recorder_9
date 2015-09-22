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

public class TGLTrackPoint  {
    
    let PRECISION = 10.0;
    
    public var coordinate : CLLocationCoordinate2D = CLLocationCoordinate2DMake(0.0, 0.0)
    public var ele : Double = 0.0
    public var filteredEle : Double = 0.0
    public var dtime : NSDate = NSDate()
    
    
    public var hPrecision : CLLocationAccuracy = -1.0  // Bad Point
    public var vPrecision : CLLocationAccuracy = -1.0  // Bad Point
    public var distanciaOrigen : CLLocationDistance = 0.0
    public var tempsOrigen : NSTimeInterval = 0.0
    public var speed : CLLocationSpeed = 0.0
    public var filteredSpeed : CLLocationSpeed = 0.0
    public var heading : CLLocationDirection = 0.0
    public var distanciaPedometer : Double = 0.0
    
    public var heartRate : Double = 0.0
    public var filteredHeartRate : Double = 0.0
    public var temperatura : Double = 0.0
    
    public var activity : ActivityEnum = .Unknown
    
    
    
    
    public var selected = false
    
    var otherFormatter : NSDateFormatter;
    
    // Returns position as a CLLocation instance
    
    public init()
    {

        self.otherFormatter = NSDateFormatter();
        self.otherFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        
        self.otherFormatter.timeZone = NSTimeZone(abbreviation: "UTC")
        self.otherFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'.000Z'"

    }
    
    // MARK: - Calculated properties
    
    
    public var activityDesc : String
    {        
        return CMMotionActivity.activityDescription(self.activity)
    }
    
    public var time : String
    {
        return self.otherFormatter.stringFromDate(self.dtime);
    }
    public var location : CLLocation
    {
       return CLLocation.init(latitude: coordinate.latitude,longitude: coordinate.longitude);
    }

    public var tempsOrigenAsString :String
    {
        return TGLTrackPoint.stringFromTimeInterval(self.tempsOrigen);
    }
    
    public var xmlText : String
    {
        var str : NSMutableString = NSMutableString();
        str.appendFormat("<trkpt lat=\"%7.5f\" lon=\"%7.5f\">\n", self.coordinate.latitude, self.coordinate.longitude)
        
        var timeString :String = self.time.stringByReplacingOccurrencesOfString(" ",  withString: "").stringByReplacingOccurrencesOfString("\n",withString: "").stringByReplacingOccurrencesOfString("\r",withString: "")
        
        str.appendFormat("<ele>%3.0f</ele>\n", self.ele)
        str.appendFormat("<time>\(timeString)</time>\n")
        
        if self.hPrecision != -1
        {
            str.appendFormat("<hdop>%7.2f</hdop>\n", self.hPrecision)
        }
        
        if self.vPrecision != -1
        {
            str.appendFormat("<vdop>%7.2f</vdop>\n", self.vPrecision)
        }
        
        
        str.appendString("<extensions>\n")
        str.appendFormat("<gpxdata:hr>%4.2f</gpxdata:hr>\n", self.heartRate)
        str.appendFormat("<gpxdata:temp>%4.2f</gpxdata:temp>\n", self.temperatura)
        str.appendFormat("<gpxdata:distance>%8.2f</gpxdata:distance>\n", self.distanciaOrigen)
        str.appendFormat("<tracesdata:activity>%@</tracesdata:activity>\n", self.activityDesc)
        str.appendFormat("<tracesdata:heading>%8.2f</tracesdata:heading>\n", self.heading)
        str.appendFormat("<tracesdata:distancePedometer>%8.2f</tracesdata:distancePedometer>\n", self.distanciaPedometer)
        str.appendString("</extensions>\n")
        str.appendString("</trkpt>\n")
        
        return str as String;
    }
    
    // TODO : - Add UTM support creating a computed UTM coordinate
    
    //@property (nonatomic) UTMCoordinates utm



    // MARK: - Test and compare functions
    
    public func isEqualTo (pt : TGLTrackPoint?) -> (Bool)
    {
        if let pt0 = pt{
            return fabs(self.distanciaOrigen - pt0.distanciaOrigen) < PRECISION
        }
        else
        {
            return false;
        }
    }

    public func compareDistance (pt : TGLTrackPoint) -> (NSComparisonResult)
    {
        if self.distanciaOrigen < pt.distanciaOrigen
        {
            return NSComparisonResult.OrderedAscending;
        }
        else if self.distanciaOrigen > pt.distanciaOrigen
        {
            return NSComparisonResult.OrderedDescending;
        }
        else
        {
            return NSComparisonResult.OrderedSame;
        }
        
    }

    // MARK: - Utilities functions
    
    public func distanceFrom ( pt : TGLTrackPoint) -> (CLLocationDistance)   // In Meters
    {
        return self.location.distanceFromLocation(pt.location);
    }
    
    public func distanceFromLocation (loc: CLLocation) -> (CLLocationDistance) // In Meters
    {
        return self.location.distanceFromLocation(loc);
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
    
    func getUrl(server : String) -> NSURL? {
        
            var fmt = NSDateFormatter()
            fmt.dateFormat = "yyyy-MM-dd+HH:mm:ss"
            var sdate = fmt.stringFromDate(self.dtime)
            
            let uuid = UIDevice.currentDevice().identifierForVendor
            let suuid = uuid!.UUIDString
            
            let param = String(format: "%@?id=%@&date=%@&lat=%0.5f&lon=%0.5f&ele=%0.2f", server,suuid, sdate, self.coordinate.latitude, self.coordinate.longitude, self.ele)
        
            return NSURL(string: param)
    }
    
    func toJSON() -> NSDictionary {
        
        let tpj = NSMutableDictionary()
        tpj.setJSONPoint(trackPoint: self)
        return tpj
        
    }

    // MARK: -  Class utilities
    
    class func stringFromTimeInterval (interval: NSTimeInterval) -> (String){ // Veure de convertir-ho a type o
        let ti : Int = Int(interval)
        let seconds : Int  = ti % 60;
        let minutes : Int  = (ti / 60) % 60;
        let hours : Int = (ti / 3600);
        return "\(hours):\(minutes):\(seconds)"

    }
        
    
}
