//
//  RecorderTests.swift
//  RecorderTests
//
//  Created by Francisco Gorina Vanrell on 30/1/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit
import XCTest

import MapKit

import Recorder

class RecorderTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testTGLTrackPoint() {
        // Test functions in TGLTrackPoint
        
        var pt : TGLTrackPoint = TGLTrackPoint()
        
        // Change some data
        pt.coordinate = CLLocationCoordinate2DMake(42.48577, 2.11688)
        pt.ele = 1643.0
        pt.filteredEle = 1640.0
        
        pt.hPrecision = 5.0
        pt.vPrecision = 3.0
        
        pt.distanciaOrigen = 10000.0
        pt.tempsOrigen = 3850.0
        
        pt.speed = 10.3
        pt.filteredSpeed = 10.0
        pt.heading = 180.0
        
        pt.heartRate = 151.0
        pt.filteredHeartRate = 150.0
        pt.temperatura = 27.5
        
        // Get computed variables to ckeck
        
        var timeString = pt.time;
        var location = pt.location;
        var tempsString = pt.tempsOrigenAsString;
        
        println("Time String : \(timeString)")
        println("Location : \(location)")
        println("Temps : \(tempsString)")
        println("XML : \(pt.xmlText)")
        
        XCTAssertEqual(location.coordinate.latitude, pt.coordinate.latitude)
        XCTAssertEqual(location.coordinate.longitude, pt.coordinate.longitude)
    
        
    }
    
    func testPreview(){
        
        // Primer creem una track
        
        let track = TGLTrack()
        
        let bundle = NSBundle.mainBundle()
        let urls = bundle.URLForResource("Movescount_track", withExtension: "gpx")
        
        XCTAssertNotNil(urls, "URL not loaded")
        
        if let url = urls {
            
            if let data = NSData(contentsOfURL: url){
                track.loadData(data, fromFilesystem:FileOrigin.Document, withPath:url.path!)
                
                XCTAssertNotNil(track.data, "Track data nil")

                
                XCTAssertGreaterThan(track.data.count, 0, "Error in number of points in track")
                
                
                let img = track.imageWithWidth(250, height:250)
                
                 
                
                XCTAssertNotNil(img, "Image  null")
                
                let w = img.size.width
                let h = img.size.height
                
                XCTAssertEqualWithAccuracy(250, w, 0.1, "Width not OK")
                XCTAssertEqualWithAccuracy(250, h, 0.1, "height not OK")
            }
        }
    }
    
}
