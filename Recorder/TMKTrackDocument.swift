//
//  TMKTrackDocument.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 1/2/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit

open class TMKTrackDocument: UIDocument {
    
    open unowned var track : TGLTrack;
    
    // Els inicialitzadors canvien de la versió de O-C per obligar a incloure la track
    
    init(track : TGLTrack){
        self.track = track;
        super.init(fileURL:URL(fileURLWithPath:track.path!));
    }
    
    init(fileURL url: URL, track:TGLTrack) {
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
    
    open override func contents(forType typeName: String) throws -> Any {
        return self.track;
    }
    
    //
    // Sustituim aquest metode per poder parsejar a mida que llegim de l'arxiu
    //
    
    open override func read(from url: URL) throws {
        self.track.loadURL(url, fromFilesystem:FileOrigin.document);
        
    }
    
    
    // Aquesta operacio permet gravar sense convertir tot el document
    // De fet el contents es el mateix document.
    //
    // D'aquesta forma la traduccio a xml no cal tenir-la a memoria
    //
    
    override open func writeContents(_ contents: Any, to url: URL, for saveOperation: UIDocument.SaveOperation, originalContentsURL: URL?) throws {
        
        self.track.writeToURL(url)
    }
    
    
    open override func handleError(_ error: Error, userInteractionPermitted:Bool)
    {
        let err = error as NSError
        NSLog("Error al obrir arxiu : %@", err);
    }
    
    
    open override func updateUserActivityState(_ userActivity:NSUserActivity)
    {
        super.updateUserActivityState(userActivity);
    
    // Add selection information
    
    }

    
   
}
