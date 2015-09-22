//
//  TMKTrackDocument.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 1/2/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit

public class TMKTrackDocument: UIDocument {
    
    public unowned var track : TGLTrack;
    
    // Els inicialitzadors canvien de la versió de O-C per obligar a incloure la track
    
    init(track : TGLTrack){
        self.track = track;
        super.init(fileURL:NSURL(fileURLWithPath:track.path!));
    }
    
    init(fileURL url: NSURL, track:TGLTrack) {
        self.track = track;
        super.init(fileURL:url);
    }
    
    // MARK : UIDocument functions
    
    // Atencio, el contents es el track. Per tant hem de implementar
    //
    //      writeContents:toURL:forSaveOperation:originalContentsURL:error:
    //
    //   de forma que pugui comprendre les dades.
    //
    //  El safe writing ja el fa writeContents:andAttributes:safelyToURL:forSaveOperation:error:
    //
    //
    
    public override func contentsForType(typeName: String) throws -> AnyObject {
        return self.track;
    }
    
    //
    // Sustituim aquest metode per poder parsejar a mida que llegim de l'arxiu
    //
    
    public override func readFromURL(url: NSURL) throws {
        self.track.loadURL(url, fromFilesystem:FileOrigin.Document);
        
    }
    
    
    // Aquesta operacio permet gravar sense convertir tot el document
    // De fet el contents es el mateix document.
    //
    // D'aquesta forma la traduccio a xml no cal tenir-la a memoria
    //
    
    override public func writeContents(contents: AnyObject, toURL url: NSURL, forSaveOperation saveOperation: UIDocumentSaveOperation, originalContentsURL: NSURL?) throws {
        
        self.track.writeToURL(url)
    }
    
    
    public override func handleError(error: NSError, userInteractionPermitted:Bool)
    {
    
        NSLog("Error al obrir arxiu : %@", error);
    }
    
    
    public override func updateUserActivityState(userActivity:NSUserActivity)
    {
        super.updateUserActivityState(userActivity);
    
    // Add selection information
    
    }

    
   
}
