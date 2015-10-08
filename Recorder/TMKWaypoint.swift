//
//  TMKWaypoint.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 2/2/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit
import MapKit

public enum WaypointType{
    case Waypoint
    case Start
    case End
    case StartSelection
    case EndSelection
    case Custom
}

public class TMKWaypoint: TGLTrackPoint {
    
    // Some public properties
    
    public var type = WaypointType.Waypoint
    public var color = MKPinAnnotationColor.Red
    public var title = "Waypoint"
    public var subtitle : String?
    public var notes : String?
    public weak var track : TGLTrack?
    
    
    override init(){
        super.init();
    }
    
    // Computed Properties
    
    public var plainText : String{
        
        var str = self.title;
        
        
        let timeString :String = self.time.stringByReplacingOccurrencesOfString(" ",  withString: "").stringByReplacingOccurrencesOfString("\n",withString: "").stringByReplacingOccurrencesOfString("\r",withString: "")
        
        
        str += String(format: "\nLon = %7.5f Lat = %7.5f",self.coordinate.longitude, self.coordinate.latitude)
        
        
        str += String(format:"Elevation %3.0f m\n", self.ele)
        str += "Tiempo \(timeString)\n"
        if let sub = self.subtitle {
            str += (sub + "\n")
        }
        
        if let not = self.notes {
            str += (not + "\n")
        }
        
        return str
        
    }

    
    override public var xmlText : String
        {
            let str : NSMutableString = NSMutableString()
            str.appendFormat("<wpt lat=\"%7.5f\" lon=\"%7.5f\">\n", self.coordinate.latitude, self.coordinate.longitude)
            
            let timeString :String = self.time.stringByReplacingOccurrencesOfString(" ",  withString: "").stringByReplacingOccurrencesOfString("\n",withString: "").stringByReplacingOccurrencesOfString("\r",withString: "")
            
            str.appendFormat("<ele>%3.0f</ele>\n", self.ele)
            str.appendFormat("<time>\(timeString)</time>\n")

            str.appendFormat("<name>%@</name>\n",self.title)
            
            
            if let not = self.notes{
                str.appendFormat("<desc>%@</desc>\n",not)
            }
            

            
            str.appendString("<extensions>\n")
            str.appendFormat("<gpxdata:hr>%4.2f</gpxdata:hr>\n", self.heartRate)
            str.appendFormat("<gpxdata:temp>%4.2f</gpxdata:temp>\n", self.temperatura)
            str.appendFormat("<gpxdata:distance>%8.2f</gpxdata:distance>\n", self.distanciaOrigen)
            str.appendString("</extensions>\n")
            str.appendString("</wpt>\n")
            
            return str as String;
    }
    
    public var xmlFileText : String
    {
        let str : NSMutableString = NSMutableString()

    
        str.appendString("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
        str.appendString("<gpx xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.cluetrust.com/XML/GPXDATA/1/0 http://www.cluetrust.com/Schemas/gpxdata10.xsd\" xmlns:gpxdata=\"http://www.cluetrust.com/XML/GPXDATA/1/0\" version=\"1.1\" creator=\"Movescount - http://www.movescount.com\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n");
    
        str.appendString(self.xmlText)
    
        str.appendString("</gpx>\n")
    
    
        return str as String
    
    }


    // Public classes
    
    public class func newWaypointFromTrackPoint(_trackPoint tp: TGLTrackPoint) -> (TMKWaypoint){
        
        
        let tw = TMKWaypoint()
        
        tw.coordinate = tp.coordinate;
        tw.ele = tp.ele;
        tw.dtime = tp.dtime;
        tw.distanciaOrigen = tp.distanciaOrigen;
        tw.tempsOrigen = tp.tempsOrigen;
        tw.heartRate = tp.heartRate;
        tw.temperatura = tp.temperatura;
        
        
        return tw;
    }
    
    public func buildNewData(){
        
        if let tr = self.track {
            let ip = tr.nearerTrackPointForLocation(self.location)
            
            let pt = tr.data[ip]
            
            self.distanciaOrigen = pt.distanciaOrigen
            self.tempsOrigen = pt.tempsOrigen
            if(self.ele == 0){
                self.ele = pt.ele
            }
            
            self.subtitle = String(format:"Ele %#3.0f m - %#3.2f Km - %@",self.ele,self.distanciaOrigen/1000.0,self.tempsOrigenAsString)
        }
    }
    
}
