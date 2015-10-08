//
//  TMKHeartRateMonitor.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 15/3/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit
import CoreBluetooth

public class TMKHeartRateMonitor: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - Properties
    
    //weak var delegate : ViewController?
    public var scanning : Bool
    public var connected : Bool
    
    var centralManager : CBCentralManager?
    var discoveredPeripheral : CBPeripheral?
    var data : NSMutableData
    
    var hr : Int = 0
    var battery : Int = 0
    
    // MARK: - Structures
    
    struct hrdata {
        var flags : UInt8
        var hr : UInt8
        var rr : [UInt16]
    }
    
    struct battData {
        var value : UInt8
    }
    
    // MARK: - Constants
    
   static  public let kScanningHRStartedNotification = "kScanningHRStartedNotification"
    static  public let kScanningHRStopedNotification = "kScanningHRStopedNotification"
    
    static  public let kSubscribedToHRStartedNotification = "kSubscribedToHRStartedNotification"
    static  public let kSubscribedToHRStopedNotification = "kSubscribedToHRStopedNotification"
    
    static  public let kServicesHRDiscoveredNotification = "kSservicesHRDiscoveredNotification"
    static  public let kHRReceivedNotification = "kHRReceivedNotification"
    static  public let kBatteryReceivedNotification = "kBatteryReceivedNotification"
    
    static  public let kUUIDHeartRateService = "180D"
    static  public let kUUIDHeartRateVariable = "2A37"
    
    static  public let kUUIDBatteryLevelService = "180F"
    static  public let kUUIDBatteryLevelVariable = "2A19"
    
    static  public let kUUIDMioLinkHRZonesService = "6C721838-5BF1-4F64-9170-381C08EC57EE"
    static  public let kUUIDMioLinkHRZonesVariable = "6C722A82-5BF1-4F64-9170-381C08EC57EE"
    
    static  public let kLastHRDeviceAccessedKey = "XHRDEVICE"
    
    // MARK:  - Public
    
    public override init()
    {
        self.scanning = false
        self.connected = false
        self.data =  NSMutableData()
        self.hr = 0
        self.battery = 0
//        self.delegate = nil
        
        super.init()
    }
    
    public func startScanning()
    {
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.data = NSMutableData()
        
        
    }
    public func stopScanning()
    {
        self.scanning = false
        if let cm = self.centralManager {
            cm.stopScan()
        }
        self.cleanup()
        self.centralManager = nil
        
    }
    
    
    
    
    // MARK: - Central Manager Delegate
    
    public func centralManagerDidUpdateState(central : CBCentralManager)
    {
        
        self.scanning = false;
        
        
        if central.state != CBCentralManagerState.PoweredOn {
            self.sendNotification(TMKHeartRateMonitor.kSubscribedToHRStopedNotification, object:nil);
            return;
        }
        
        if central.state == CBCentralManagerState.PoweredOn {
            
            // Check to see if we have a device already registered to avoid scanning
            
            let store = NSUserDefaults.standardUserDefaults()
            let device = store.stringForKey(TMKHeartRateMonitor.kLastHRDeviceAccessedKey)
            
            if device != nil    // Try to connect to last connected peripheral
            {
                
                let ids = [NSUUID(UUIDString:device!)!]
                

                
                let devs : [CBPeripheral] = self.centralManager!.retrievePeripheralsWithIdentifiers(ids)
                if devs.count > 0
                {
                    let peri : CBPeripheral = devs[0]
                    
                    self.centralManager(central,  didDiscoverPeripheral:peri, advertisementData:["Heelo":"Hello"],  RSSI:NSNumber())
                    return
                }
                
            }
            
            // If we are here we may try to look for a connected device known to the central manager
            
            let services = [CBUUID(string:TMKHeartRateMonitor.kUUIDHeartRateService)]
            let moreDevs : [CBPeripheral] = self.centralManager!.retrieveConnectedPeripheralsWithServices(services) 
            
            if  moreDevs.count > 0
            {
                let peri : CBPeripheral = moreDevs[0]
                
                self.centralManager(central, didDiscoverPeripheral:peri,  advertisementData:["Hello": "Hello"],  RSSI:NSNumber(double: 0.0))
                return
            }
            
            // OK, nothing works so we go for the scanning
            
            self.doRealScan()
            
        }
        
    }
    
    func doRealScan()
    {
        self.scanning = true
        
        
        // Scan for devices    @[[CBUUID UUIDWithString:@"1819"]]
        self.centralManager!.scanForPeripheralsWithServices([CBUUID(string:TMKHeartRateMonitor.kUUIDHeartRateService)], options:[CBCentralManagerScanOptionAllowDuplicatesKey : false ])
        
        self.sendNotification(TMKHeartRateMonitor.kScanningHRStartedNotification, object:nil)
        
        NSLog("Scanning started")
    }
    
    
    public func centralManager(central: CBCentralManager,
        didDiscoverPeripheral peripheral: CBPeripheral,
        advertisementData: [String : AnyObject],
        RSSI: NSNumber){
            
            NSLog("Discovered %@ - %@", peripheral.name!, peripheral.identifier);
            
            self.discoveredPeripheral = peripheral;
            NSLog("Connecting to peripheral %@", peripheral);
            self.centralManager!.connectPeripheral(peripheral, options:nil)
            self.sendNotification(TMKHeartRateMonitor.kServicesHRDiscoveredNotification , object:nil)
            
            
    }
    
    
    func connectPeripheral(peripheral : CBPeripheral)
    {
        
        NSLog("Connecting to HR peripheral %@", peripheral);
        
        self.discoveredPeripheral = peripheral;
        self.centralManager!.connectPeripheral(peripheral, options:nil)
    }
    
    public func centralManager(central : CBCentralManager, didFailToConnectPeripheral peripheral : CBPeripheral,  error : NSError?)
    {
        
        NSLog("Failed to connect to HR monitor %@", peripheral.identifier);
        
        if !self.scanning // If not scanning try to do it
        {
            self.doRealScan()
            
        }
        else
        {
            
            self.cleanup()
        }
        
    }
    
    public func centralManager(central : CBCentralManager, didConnectPeripheral peripheral :CBPeripheral){
        NSLog("Connected");
        
        if self.scanning
        {
            self.centralManager!.stopScan()
            self.scanning = false
            NSLog("Scanning stopped")
        }
        
        self.data.length = 0
        
        peripheral.delegate = self;
        
        //[peripheral discoverServices:nil];
        
        
        peripheral.discoverServices([CBUUID(string:TMKHeartRateMonitor.kUUIDHeartRateService),CBUUID(string:TMKHeartRateMonitor.kUUIDBatteryLevelService), CBUUID(string:TMKHeartRateMonitor.kUUIDMioLinkHRZonesService)])
    }
    
    public func centralManager(central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: NSError?)
        
    {
        
        self.sendNotification(TMKHeartRateMonitor.kSubscribedToHRStopedNotification, object:nil)
        
        if self.connected  // Try to regain the connection with the last device
        {
            let store = NSUserDefaults.standardUserDefaults()
            let device = store.stringForKey(TMKHeartRateMonitor.kLastHRDeviceAccessedKey)
            
            if(device != nil)   // Try to connect to last connected peripheral
            {
                
                let ids  = [NSUUID(UUIDString:device!)!]
                let devs : [CBPeripheral] = self.centralManager!.retrievePeripheralsWithIdentifiers(ids) 
                
                if devs.count > 0
                {
                    let peri : CBPeripheral = devs[0]
                    
                    self.centralManager(central,  didDiscoverPeripheral:peri,  advertisementData:["Hello" : "Hello"],  RSSI:NSNumber())
                    return;
                }
            }
            
            
        }
        
        
        self.discoveredPeripheral = nil;
    }
    
    //MARK: - CBPeripheralDelegate
    
    public func peripheral(peripheral: CBPeripheral,
        didDiscoverServices error: NSError?)
    {
        

        if let serv = peripheral.services{
        for sr in serv
        {
            NSLog("Service %@", sr.UUID.UUIDString)
            
            if sr.UUID.UUIDString == TMKHeartRateMonitor.kUUIDHeartRateService
            {
                let charUUIDs = [CBUUID(string:TMKHeartRateMonitor.kUUIDHeartRateVariable)]
                peripheral.discoverCharacteristics(charUUIDs, forService:sr)
            }
                
            else if sr.UUID.UUIDString == TMKHeartRateMonitor.kUUIDBatteryLevelService
            {
                let charUUIDs = [CBUUID(string:TMKHeartRateMonitor.kUUIDBatteryLevelVariable)]
                peripheral.discoverCharacteristics(charUUIDs, forService:sr)
            }
            else if sr.UUID.UUIDString == TMKHeartRateMonitor.kUUIDMioLinkHRZonesService
            {
                let charUUIDs = [CBUUID(string:TMKHeartRateMonitor.kUUIDMioLinkHRZonesVariable)]
                peripheral.discoverCharacteristics(charUUIDs, forService:sr)
            }
        }
        }
        
    }
    
    
    public func peripheral(peripheral: CBPeripheral,
        didDiscoverCharacteristicsForService service: CBService,
        error: NSError?)
    {
        
        // Sembla una bona conexio, la guardem per mes endavant
        let store = NSUserDefaults.standardUserDefaults()
        let idPeripheral = peripheral.identifier.UUIDString
        store.setObject(idPeripheral, forKey:TMKHeartRateMonitor.kLastHRDeviceAccessedKey)
        
        if let characteristics = service.characteristics {
            var cho : CBCharacteristic?
            
            if characteristics.count > 0{
                cho = characteristics[0]
            }
            
            if let ch = cho {
                
                if ch.UUID.UUIDString == TMKHeartRateMonitor.kUUIDHeartRateVariable
                {
                    peripheral.setNotifyValue(true, forCharacteristic:ch)
                    self.sendNotification(TMKHeartRateMonitor.kSubscribedToHRStartedNotification, object:nil)
                    self.connected = true
                }
                else if ch.UUID.UUIDString == TMKHeartRateMonitor.kUUIDBatteryLevelVariable
                {
                    peripheral.readValueForCharacteristic(ch)
                }
                else if ch.UUID.UUIDString == TMKHeartRateMonitor.kUUIDMioLinkHRZonesVariable
                {
                    peripheral.readValueForCharacteristic(ch)
                    
                }
            }
        }
        
    }
    
    public func peripheral(peripheral: CBPeripheral,
        didUpdateValueForCharacteristic characteristic: CBCharacteristic,
        error: NSError?){
            
            // Primer obtenim el TMKPeripheralObject
            
            if characteristic.UUID.UUIDString == TMKHeartRateMonitor.kUUIDHeartRateVariable  // HR
            {
                
                var dades = hrdata(flags: 0, hr: 0, rr: [0])
                
                
                characteristic.value!.getBytes(&dades, length: 2)
                
                let value = dades.hr
                //UInt8   flags = dades ->flags;
                
                self.hr = Int(value)
                
                /* El codi a continuacio permet accedir als valors de RR
                Com que no els fem servir, simplement ho ignorem.
                
                NSUInteger len = [characteristic.value length];     // Longitut total de ls dades rebudes
                NSUInteger nRR = (len-2)/2; // Calula el numero de elements RR que tenim. Cada u es un uint16
                
                for(NSUInteger i = 0; i < nRR; i++)
                {
                uint16_t rr = dades->rr[i];
                NSLog(@"HR %d - rr %d", value, rr);
                
                }
                
                */
                self.sendNotification(TMKHeartRateMonitor.kHRReceivedNotification, object:self.hr)
            }
                
            else if characteristic.UUID.UUIDString==TMKHeartRateMonitor.kUUIDBatteryLevelVariable  // Battery
            {
                
                var dades = battData(value: 0)
                characteristic.value!.getBytes(&dades, length: 1)
                
                self.battery = Int(dades.value)
                
                self.sendNotification(TMKHeartRateMonitor.kBatteryReceivedNotification, object:self.battery)
                
            }
            
            //      De moment passem de això
            
            
            //    else if([characteristic.UUID.UUIDString isEqualToString:kUUIDMioLinkHRZonesVariable])
            //    {
            //    UInt8 *dades;
            //
            //    NSLog(@"Rebut HR data %@" ,characteristic.value.description);
            //    dades = (UInt8 *)[characteristic.value bytes];
            //
            //    NSLog(@"Tipus control : %d ", dades[4]);
            //
            //
            //
            //    for (int i = 6; i <= 10; i++)
            //    {
            //    NSLog(@"Heart Rate Zone : %d - %d bpm", (i-5), dades[i]);
            //    }
            //
            //    for (int i = 11; i <= 12; i++)
            //    {
            //    NSLog(@"Heart Rate Limit : %u - %d bpm", (i-10), dades[i]);
            //    }
            //
            //
            //    }
    }
    
    //MARK: - Utilities
    
    func sendNotification(not:String, object: AnyObject?)
    {
        if GlobalConstants.debug{
            if let obj : NSObject = object as? NSObject{
                NSLog("Sending %@ (%@)", not, obj)
            }
            else
            {
                NSLog("Sending %@", not)
                
            }
        }
        let notification = NSNotification(name:not, object:object)
        NSNotificationCenter.defaultCenter().postNotification(notification)
    }
    
    
    
    public func cleanup() {
        
        // See if we are subscribed to a characteristic on the peripheral
        
        if let thePeripheral = self.discoveredPeripheral  {
            if let theServices = thePeripheral.services {
                
                for service : CBService in theServices {
                    
                    if let theCharacteristics = service.characteristics {
                        for characteristic : CBCharacteristic in theCharacteristics {
                            if characteristic.UUID == CBUUID(string:"2A67") {
                                if characteristic.isNotifying {
                                    self.discoveredPeripheral!.setNotifyValue(false, forCharacteristic:characteristic)
                                    //return;
                                }
                            }
                        }
                    }
                }
                
            }
            if let peri = self.discoveredPeripheral {
                if let central = self.centralManager{
                    central.cancelPeripheralConnection(peri)
                }
            }
        }
        
        self.connected = false
        self.discoveredPeripheral = nil;
        
        self.sendNotification(TMKHeartRateMonitor.kScanningHRStopedNotification,  object:nil)
        self.sendNotification(TMKHeartRateMonitor.kSubscribedToHRStopedNotification, object:nil)
    }
    
}
