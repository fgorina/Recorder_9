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
    
    // MARK: Debug
    
    let debug = false
    
    // MARK: - Properties
    
    weak var delegate : ViewController?
    public var scanning : Bool
    public var connected : Bool
    
    var centralManager : CBCentralManager?
    var discoveredPeripheral : CBPeripheral?
    var data : NSMutableData
    
    var hr : Int
    var battery : Int
    
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
    
    public let kScanningHRStartedNotification = "kScanningHRStartedNotification"
    public let kScanningHRStopedNotification = "kScanningHRStopedNotification"
    
    public let kSubscribedToHRStartedNotification = "kSubscribedToHRStartedNotification"
    public let kSubscribedToHRStopedNotification = "kSubscribedToHRStopedNotification"
    
    public let kServicesHRDiscoveredNotification = "kSservicesHRDiscoveredNotification"
    public let kHRReceivedNotification = "kHRReceivedNotification"
    public let kBatteryReceivedNotification = "kBatteryReceivedNotification"
    
    public let kUUIDHeartRateService = "180D"
    public let kUUIDHeartRateVariable = "2A37"
    
    public let kUUIDBatteryLevelService = "180F"
    public let kUUIDBatteryLevelVariable = "2A19"
    
    public let kUUIDMioLinkHRZonesService = "6C721838-5BF1-4F64-9170-381C08EC57EE"
    public let kUUIDMioLinkHRZonesVariable = "6C722A82-5BF1-4F64-9170-381C08EC57EE"
    
    public let kLastHRDeviceAccessedKey = "XHRDEVICE"
    
    // MARK:  - Public
    
    public override init()
    {
        self.scanning = false
        self.connected = false
        self.data =  NSMutableData()
        self.hr = 0
        self.battery = 0
        self.delegate = nil
        
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
            self.sendNotification(kSubscribedToHRStopedNotification, object:nil);
            return;
        }
        
        if central.state == CBCentralManagerState.PoweredOn {
            
            // Check to see if we have a device already registered to avoid scanning
            
            let store = NSUserDefaults.standardUserDefaults()
            let device = store.stringForKey(kLastHRDeviceAccessedKey)
            
            if device != nil    // Try to connect to last connected peripheral
            {
                
                let ids = NSArray(object:CBUUID(string:device))
                let devs : [CBPeripheral] = self.centralManager!.retrievePeripheralsWithIdentifiers(ids as [AnyObject]) as! [CBPeripheral]
                
                if devs.count > 0
                {
                    let peri : CBPeripheral = devs[0]
                    
                    let o : AnyObject? = nil
                    let n : NSNumber? = nil
                    
                    
                    self.centralManager(central,  didDiscoverPeripheral:peri, advertisementData:nil,  RSSI:nil)
                    return
                }
            }
            
            // If we are here we may try to look for a connected device known to the central manager
            
            let services = NSArray(object:CBUUID(string:kUUIDHeartRateService))
            let moreDevs : [CBPeripheral] = self.centralManager!.retrieveConnectedPeripheralsWithServices(services as [AnyObject]) as! [CBPeripheral]
            
            if  moreDevs.count > 0
            {
                let peri : CBPeripheral = moreDevs[0]
                
                self.centralManager(central, didDiscoverPeripheral:peri,  advertisementData:nil,  RSSI:nil)
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
        self.centralManager!.scanForPeripheralsWithServices([CBUUID(string:kUUIDHeartRateService)], options:[CBCentralManagerScanOptionAllowDuplicatesKey : false ])
        
        self.sendNotification(kScanningHRStartedNotification, object:nil)
        
        NSLog("Scanning started")
    }
    
    
    public func centralManager(central: CBCentralManager!,
        didDiscoverPeripheral peripheral: CBPeripheral!,
        advertisementData: [NSObject : AnyObject]!,
        RSSI: NSNumber!){
            
            NSLog("Discovered %@ - %@", peripheral.name, peripheral.identifier);
            
            self.discoveredPeripheral = peripheral;
            NSLog("Connecting to peripheral %@", peripheral);
            self.centralManager!.connectPeripheral(peripheral, options:nil)
            self.sendNotification(kServicesHRDiscoveredNotification , object:nil)
            
            
    }
    
    
    func connectPeripheral(peripheral : CBPeripheral)
    {
        
        NSLog("Connecting to HR peripheral %@", peripheral);
        
        self.discoveredPeripheral = peripheral;
        self.centralManager!.connectPeripheral(peripheral, options:nil)
    }
    
    public func centralManager(central : CBCentralManager, didFailToConnectPeripheral peripheral : CBPeripheral,  error : NSError)
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
        
        
        peripheral.discoverServices([CBUUID(string:kUUIDHeartRateService),CBUUID(string:kUUIDBatteryLevelService), CBUUID(string:kUUIDMioLinkHRZonesService)])
    }
    
    public func centralManager(central: CBCentralManager!,
        didDisconnectPeripheral peripheral: CBPeripheral!,
        error: NSError!)
        
    {
        
        self.sendNotification(kSubscribedToHRStopedNotification, object:nil)
        
        if self.connected  // Try to regain the connection with the last device
        {
            let store = NSUserDefaults.standardUserDefaults()
            let device = store.stringForKey(kLastHRDeviceAccessedKey)
            
            if(device != nil)   // Try to connect to last connected peripheral
            {
                
                let ids  = NSArray(object:CBUUID(string:device))
                let devs : [CBPeripheral] = self.centralManager!.retrievePeripheralsWithIdentifiers(ids as [AnyObject]) as! [CBPeripheral]
                
                if devs.count > 0
                {
                    let peri : CBPeripheral = devs[0]
                    
                    self.centralManager(central,  didDiscoverPeripheral:peri,  advertisementData:nil,  RSSI:nil)
                    return;
                }
            }
            
            
        }
        
        
        self.discoveredPeripheral = nil;
    }
    
    //MARK: - CBPeripheralDelegate
    
    public func peripheral(peripheral: CBPeripheral!,
        didDiscoverServices error: NSError!)
    {
        
        let serv = peripheral.services as! [CBService]
        
        for sr in serv
        {
            NSLog("Service %@", sr.UUID.UUIDString)
            
            if sr.UUID.UUIDString == kUUIDHeartRateService
            {
                let charUUIDs = [CBUUID(string:kUUIDHeartRateVariable)]
                peripheral.discoverCharacteristics(charUUIDs, forService:sr)
            }
                
            else if sr.UUID.UUIDString == kUUIDBatteryLevelService
            {
                let charUUIDs = [CBUUID(string:kUUIDBatteryLevelVariable)]
                peripheral.discoverCharacteristics(charUUIDs, forService:sr)
            }
            else if sr.UUID.UUIDString == kUUIDMioLinkHRZonesService
            {
                let charUUIDs = [CBUUID(string:kUUIDMioLinkHRZonesVariable)]
                peripheral.discoverCharacteristics(charUUIDs, forService:sr)
            }
        }
        
    }
    
    
    public func peripheral(peripheral: CBPeripheral!,
        didDiscoverCharacteristicsForService service: CBService!,
        error: NSError!)
    {
        
        // Sembla una bona conexio, la guardem per mes endavant
        let store = NSUserDefaults.standardUserDefaults()
        let idPeripheral = peripheral.identifier.UUIDString
        store.setObject(idPeripheral, forKey:kLastHRDeviceAccessedKey)
        
        if let characteristics = service.characteristics as? [CBCharacteristic]{
            var cho : CBCharacteristic?
            
            if characteristics.count > 0{
                cho = characteristics[0]
            }
            
            if let ch = cho {
                
                if ch.UUID.UUIDString == kUUIDHeartRateVariable
                {
                    peripheral.setNotifyValue(true, forCharacteristic:ch)
                    self.sendNotification(kSubscribedToHRStartedNotification, object:nil)
                    self.connected = true
                }
                else if ch.UUID.UUIDString == kUUIDBatteryLevelVariable
                {
                    peripheral.readValueForCharacteristic(ch)
                }
                else if ch.UUID.UUIDString == kUUIDMioLinkHRZonesVariable
                {
                    peripheral.readValueForCharacteristic(ch)
                    
                }
            }
        }
        
    }
    
    public func peripheral(peripheral: CBPeripheral!,
        didUpdateValueForCharacteristic characteristic: CBCharacteristic!,
        error: NSError!){
            
            // Primer obtenim el TMKPeripheralObject
            
            if characteristic.UUID.UUIDString == kUUIDHeartRateVariable  // HR
            {
                
                var dades = hrdata(flags: 0, hr: 0, rr: [0])
                
                
                characteristic.value.getBytes(&dades, length: 2)
                
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
                self.sendNotification(kHRReceivedNotification, object:self.hr)
            }
                
            else if characteristic.UUID.UUIDString==kUUIDBatteryLevelVariable  // Battery
            {
                
                var dades = battData(value: 0)
                characteristic.value.getBytes(&dades, length: 1)
                
                self.battery = Int(dades.value)
                
                self.sendNotification(kBatteryReceivedNotification, object:self.battery)
                
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
        if self.debug{
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
                
                for service : CBService in theServices as! [CBService]{
                    
                    if let theCharacteristics = service.characteristics {
                        for characteristic : CBCharacteristic in service.characteristics as! [CBCharacteristic] {
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
        
        self.sendNotification(kScanningHRStopedNotification,  object:nil)
        self.sendNotification(kSubscribedToHRStopedNotification, object:nil)
    }
    
}