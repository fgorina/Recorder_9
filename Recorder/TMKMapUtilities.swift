//
//  TMKMapUtilities.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 5/11/15.
//  Copyright © 2015 Paco Gorina. All rights reserved.
//

import Foundation
import CoreMotion
import MapKit

struct IPoint {
    var x : Int
    var y : Int
}

struct TileCoordinateBounds {
    var minCoordinates : CLLocationCoordinate2D
    var maxCoordinates : CLLocationCoordinate2D
}

class TMKMapUtilities{
    
    var tileSize = 256
    var initialResolution = 2.0 * M_PI * 6378137.0 / 256.0
    var originShift = floor(2.0 * M_PI * 6378137.0) / 2.0
    
    
    func metersForLocation(_ loc : CLLocationCoordinate2D) -> CGPoint {
        
        let  mx = loc.longitude * self.originShift / 180.0
        
        var my = log(tan((90.0 + loc.latitude) * M_PI / 360.0))/(M_PI/180.0)
        my = my * originShift / 180.0;
        
        return CGPoint(x:CGFloat(mx), y:CGFloat(my))
        
    }
    
    func locationForMeters(_ pt : CGPoint) -> CLLocationCoordinate2D {
        let lon = (Double(pt.x) / self.originShift) * 180.0
        var lat = (Double(pt.y) / self.originShift) * 180.0
        
        lat = 180.0 / M_PI * (2.0 * atan( exp( Double(lat) * M_PI / 180.0)) - M_PI / 2.0)
        
        return CLLocationCoordinate2DMake(lat, lon)
    }
    
    func metersForPixels(_ pt : IPoint,  zoom: Int) -> CGPoint{
        
        let res = self.resolutionForZoom(zoom)
        
        let mx = Double(pt.x) * res - self.originShift
        let my = Double(pt.y) * res - self.originShift
        
        return CGPoint(x:mx, y:my)
        
    }
    
    func pixelsForMeters(_ m : CGPoint, forZoom zoom: Int) -> IPoint {
        
        
        let res = self.resolutionForZoom(zoom)
        
        let x = Int(floor((Double(m.x) + self.originShift) / res))
        let y = Int(floor((Double(m.y) + self.originShift) / res))
        
        return IPoint(x:x, y:y)
        
    }
    
    func tileForPixels(_ px : IPoint, zoom: Int) -> MKTileOverlayPath{
        
        
        let x = Int(ceil(Double(px.x) /  Double(self.tileSize)) - 1.0)
        let y = Int(ceil(Double(px.y) /  Double(self.tileSize)) - 1.0)
        
        return MKTileOverlayPath(x:x, y:y, z:zoom, contentScaleFactor: 1)
        
    }
    
    
    // Change origin of coordinates to top left
    
    func rasterFromPixels(_ p : IPoint,  forZoom zoom: Int) -> IPoint {
        
        let mapSize = self.tileSize * 2^zoom
        
        let x = p.x
        let y = mapSize - p.y
        
        return IPoint(x:x, y:y)
        
    }
    
    func tileForMeters(_ pt : CGPoint, zoom : Int) -> MKTileOverlayPath{
        
        let px = self.pixelsForMeters(pt, forZoom:zoom)
        
        return self.tileForPixels(px, zoom:zoom)
        
        
        
    }
    
    // Retorna els bounds de una tile. De fet origin son els minims.
    
    func boundsForTile( _ tile : MKTileOverlayPath) -> CGRect{
        
        var px = IPoint(x: tile.x * self.tileSize, y:tile.y * self.tileSize)
        
        let minPt = self.metersForPixels(px, zoom:tile.z)
        
        px = IPoint(x: (tile.x + 1) * self.tileSize, y:(tile.y + 1) * self.tileSize)
        let maxPt = self.metersForPixels(px, zoom:tile.z)
        
        return CGRect(x: minPt.x, y: minPt.y, width: maxPt.x-minPt.x, height: maxPt.y-minPt.y)
        
    }
    
    func latLonBoundsForTile(_ tile : MKTileOverlayPath) -> TileCoordinateBounds{
        var px = IPoint(x: tile.x * self.tileSize, y:tile.y * self.tileSize)
        
        let minPt = self.metersForPixels(px, zoom:tile.z)
        
        px = IPoint(x: (tile.x + 1) * self.tileSize, y:(tile.y + 1) * self.tileSize)
        let maxPt = self.metersForPixels(px, zoom:tile.z)
        
        return TileCoordinateBounds(minCoordinates: self.locationForMeters(minPt), maxCoordinates: self.locationForMeters(maxPt))
        
    }
    
    
    
    func resolutionForZoom(_ zoom : Int) -> Double {
        return self.initialResolution / pow(2.0, Double(zoom))
    }
    
    func zoomForPixelSize(_ pixelSize : Double) -> Int{
        for i in 0..<30 {
            if pixelSize > self.resolutionForZoom(i){
                if i != 0 {
                    return i-1
                }
                else{
                    return 0
                }
            }
        }
        return -1
    }
    
    // Retorna una tile per un punt i a un nivell de zoom
    
    func tileIncludingPoint(_ pt: CLLocationCoordinate2D, zoom:Int) -> MKTileOverlayPath{
        
        let mt = self.metersForLocation(pt)
        
        let tile = self.tileForMeters(mt, zoom:zoom)
        let gTile = self.googleTile(tile)
        
        return gTile;
        
        
    }
    
    // Retorna un array de tiles corresponents a un "quadrat"
    
    
    func tilesForRect(_ minPt:CLLocationCoordinate2D , maxPt:CLLocationCoordinate2D) -> [MKTileOverlayPath]
    {
        let minLoc = CLLocation(latitude: minPt.latitude, longitude: minPt.longitude)
        let maxLoc = CLLocation(latitude: maxPt.latitude, longitude: maxPt.longitude)
        let d = minLoc.distance(from: maxLoc)   // Això es la diagonal i defineix el zoom
        
        let zoom = self.zoomForPixelSize(d / Double(tileSize))
        
        let tile0 = self.tileIncludingPoint(minPt, zoom:zoom)
        let tile1 = self.tileIncludingPoint(maxPt, zoom:zoom)
        
        var x0 : Int
        var x1 : Int
        var y0 : Int
        var y1 : Int
        
        if tile0.x > tile1.x
        {
            x0 = tile1.x
            x1 = tile0.x
        }
        else
        {
            x0 = tile0.x
            x1 = tile1.x
        }
        
        if tile0.y > tile1.y
        {
            y0 = tile1.y
            y1 = tile0.y
        }
        else
        {
            y0 = tile0.y
            y1 = tile1.y
        }
        
        var arr = [MKTileOverlayPath]()
        
        for  x in x0..<x1{
            for  y in y0..<y1 {
                
                let path = MKTileOverlayPath(x: x, y: y, z: zoom, contentScaleFactor: 1.0)
                
                arr.append(path)
                
            }
        }
        
        return arr
    }
    
    func  googleTile(_ tile: MKTileOverlayPath) -> MKTileOverlayPath {
        
        var p = 2
        if tile.z == 0{
            p = 1
        }else{
            p = p << tile.z-1
        }
        p = p - 1
        
        return MKTileOverlayPath(x: tile.x, y: p-tile.y, z: tile.z, contentScaleFactor: 1.0)
        
    }
    
}

