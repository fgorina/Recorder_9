//
//  TMKImage.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 13/4/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit

class TMKImage: UIImage {
 
    //
    //  TMKImage.m
    //  TestMapKit
    //
    //  Created by Francisco Gorina Vanrell on 19/2/15.
    //  Copyright (c) 2015 Francisco Gorina Vanrell. All rights reserved.
    //
    
    
    
    class func  beginImageContextWithSize(size:CGSize)
    {
        if UIScreen.mainScreen().respondsToSelector("scale") {
            if UIScreen.mainScreen().scale == 2.0 {
                UIGraphicsBeginImageContextWithOptions(size, true, 2.0)
    } else {
                UIGraphicsBeginImageContext(size)
    }
    } else {
        UIGraphicsBeginImageContext(size)
    }
    }
    
    class func endImageContext()
    {
        UIGraphicsEndImageContext()
    }
    
    class func imageFromView(view : UIView) -> UIImage
    {
        self.beginImageContextWithSize(view.bounds.size)
        let hidden = view.hidden
        view.hidden = false
        view.layer.renderInContext(UIGraphicsGetCurrentContext())
        let image = UIGraphicsGetImageFromCurrentImageContext()
        self.endImageContext()
        view.hidden = hidden;
        return image
    }
    
    class func imageWithImage(image:UIImage,  scaledToSize newSize:CGSize) -> UIImage
    {
        self.beginImageContextWithSize(newSize)
        image.drawInRect(CGRectMake(0,0,newSize.width,newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        self.endImageContext()
        return newImage
    }
    
    
    class func imageFromView( view: UIView,  scaledToSize newSize:(CGSize)) -> UIImage
    {
        var image = self.imageFromView(view)
        if view.bounds.size.width != newSize.width ||
            view.bounds.size.height != newSize.height {
                image = self.imageWithImage(image ,scaledToSize:newSize);
        }
        return image
    }
    
    
    
}
