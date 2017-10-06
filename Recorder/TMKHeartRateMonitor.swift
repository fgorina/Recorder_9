//
//  TMKHeartRateMonitor.swift
//  Recorder
//
//  Created by Francisco Gorina Vanrell on 15/3/15.
//  Copyright (c) 2015 Paco Gorina. All rights reserved.
//

import UIKit
import CoreBluetooth
import HealthKit

open class TMKHeartRateMonitor: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - Properties
    
    //weak var delegate : ViewController?
    open var scanning : Bool
    open var connected : Bool
    
    var centralManager : CBCentralManager?
    var discoveredPeripheral : CBPeripheral?
    var data : NSMutableData
    
    var hr : Int = 0
    var battery : Int = 0
    
    // MARK: - Structures
    
    struct hrdata {
        var flags : UInt8
        var hr : UInt8
        var rr0 : UInt16 = 0
        var rr1 : UInt16 = 0
        var rr2 : UInt16 = 0
        var rr3 : UInt16 = 0
        var rr4 : UInt16 = 0
        var rr5 : UInt16 = 0
        var rr6 : UInt16 = 0
        var rr7 : UInt16 = 0
        var rr8 : UInt16 = 0
        var rr9 : UInt16 = 0
        
    }
    
    struct battData {
        var value : UInt8
    }
    
    
    // Devide id
    
    var manufacturer : String?
    var model : String?
    var serial : String?
    var hardwareVer : String?
    var firmwareVer : String?
    var softwareVer : String?
    
    
    // MARK: - Constants
    
    static  open let kScanningHRStartedNotification = "kScanningHRStartedNotification"
    static  open let kScanningHRStopedNotification = "kScanningHRStopedNotification"
    
    static  open let kSubscribedToHRStartedNotification = "kSubscribedToHRStartedNotification"
    static  open let kSubscribedToHRStopedNotification = "kSubscribedToHRStopedNotification"
    
    static  open let kServicesHRDiscoveredNotification = "kSservicesHRDiscoveredNotification"
    static  open let kHRReceivedNotification = "kHRReceivedNotification"
    static  open let kBatteryReceivedNotification = "kBatteryReceivedNotification"
    
    static  open let kUUIDHeartRateService = "180D"
    static  open let kUUIDHeartRateVariable = "2A37"
    static  open let kUUIDDeviceInfoService = "180A"
    static  open let kUUIDManufacturerNameVariable = "2A29"
    static  open let kUUIDModelNameVariable = "2A24"
    static  open let kUUIDSerialNumberVariable = "2A25"
    static  open let kUUIDHardwareVersion = "2A27"
    static  open let kUUIDFirmwareVersion = "2A26"
    static  open let kUUIDSoftwareVersion = "2A28"
    
    
    static  open let kUUIDBatteryLevelService = "180F"
    static  open let kUUIDBatteryLevelVariable = "2A19"
    
    static  open let kUUIDMioLinkHRZonesService = "6C721838-5BF1-4F64-9170-381C08EC57EE"
    static  open let kUUIDMioLinkHRZonesVariable = "6C722A82-5BF1-4F64-9170-381C08EC57EE"
    
    static  open let kLastHRDeviceAccessedKey = "XHRDEVICE"
    
    static open let kHeartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)
    
    static  open let kBeatsPerMinute = HKUnit(from: "count/min")
    
    
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
    
    open func startScanning()
    {
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.data = NSMutableData()
        
        
    }
    open func stopScanning()
    {
        self.scanning = false
        if let cm = self.centralManager {
            cm.stopScan()
        }
        self.cleanup()
        self.centralManager = nil
        
    }
    
    // MARK: - Central Manager Delegate
    
    open func centralManagerDidUpdateState(_ central : CBCentralManager)
    {
        
        self.scanning = false;
        
        
        if central.state != .poweredOn {
            self.sendNotification(TMKHeartRateMonitor.kSubscribedToHRStopedNotification, object:nil);
            return;
        }
        
        if central.state == .poweredOn {
            
            // Check to see if we have a device already registered to avoid scanning
            
            let store = UserDefaults.standard
            let device = store.string(forKey: TMKHeartRateMonitor.kLastHRDeviceAccessedKey)
            
            if device != nil   && false  // Try to connect to last connected peripheral
            {
                
                let ids = [UUID(uuidString:device!)!]
                
                
                
                let devs : [CBPeripheral] = self.centralManager!.retrievePeripherals(withIdentifiers: ids)
                if devs.count > 0
                {
                    let peri : CBPeripheral = devs[0]
                    
                    self.centralManager(central,  didDiscover:peri, advertisementData:["Hello":"Hello"],  rssi:NSNumber())
                    return
                }
                
            }
            
            // If we are here we may try to look for a connected device known to the central manager
            
            let services = [CBUUID(string:TMKHeartRateMonitor.kUUIDHeartRateService)]
            let moreDevs : [CBPeripheral] = self.centralManager!.retrieveConnectedPeripherals(withServices: services)
            
            if  moreDevs.count > 0
            {
                let peri : CBPeripheral = moreDevs[0]
                
                self.centralManager(central, didDiscover:peri,  advertisementData:["Hello": "Hello"],  rssi:NSNumber(value: 0.0 as Double))
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
        self.centralManager!.scanForPeripherals(withServices: [CBUUID(string:TMKHeartRateMonitor.kUUIDHeartRateService)], options:[CBCentralManagerScanOptionAllowDuplicatesKey : false ])
        
        self.sendNotification(TMKHeartRateMonitor.kScanningHRStartedNotification, object:nil)
        
        NSLog("Scanning started")
    }
    
    
    open func centralManager(_ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber){
            
            NSLog("Discovered %@ - %@", peripheral.name!, peripheral.identifier.uuidString);
            
            self.discoveredPeripheral = peripheral;
            NSLog("Connecting to peripheral %@", peripheral);
            self.centralManager!.connect(peripheral, options:nil)
            self.sendNotification(TMKHeartRateMonitor.kServicesHRDiscoveredNotification , object:nil)
            
            
    }
    
    
    func connectPeripheral(_ peripheral : CBPeripheral)
    {
        
        NSLog("Connecting to HR peripheral %@", peripheral);
        
        self.discoveredPeripheral = peripheral;
        self.centralManager!.connect(peripheral, options:nil)
    }
    
    open func centralManager(_ central : CBCentralManager, didFailToConnect peripheral : CBPeripheral,  error : Error?)
    {
        
        NSLog("Failed to connect to HR monitor %@", peripheral.identifier.uuidString);
        
        if !self.scanning // If not scanning try to do it
        {
            self.doRealScan()
            
        }
        else
        {
            
            self.cleanup()
        }
        
    }
    
    open func centralManager(_ central : CBCentralManager, didConnect peripheral :CBPeripheral){
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
        
        manufacturer = ""
        model = ""
        serial = ""
        hardwareVer = ""
        firmwareVer = ""
        softwareVer = ""
        
        
        peripheral.discoverServices([CBUUID(string:TMKHeartRateMonitor.kUUIDHeartRateService),CBUUID(string:TMKHeartRateMonitor.kUUIDBatteryLevelService), CBUUID(string:TMKHeartRateMonitor.kUUIDMioLinkHRZonesService), CBUUID(string:TMKHeartRateMonitor.kUUIDDeviceInfoService)])
    }
    
    open func centralManager(_ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?)
        
    {
        
        self.sendNotification(TMKHeartRateMonitor.kSubscribedToHRStopedNotification, object:nil)
        
        if self.connected  // Try to regain the connection with the last device
        {
            let store = UserDefaults.standard
            let device = store.string(forKey: TMKHeartRateMonitor.kLastHRDeviceAccessedKey)
            
            if let dev = device  // Try to connect to last connected peripheral
            {
                
                if let theId = UUID(uuidString:dev){
                    
                    let ids  = [theId]
                    let devs : [CBPeripheral] = self.centralManager!.retrievePeripherals(withIdentifiers: ids)
                    
                    if devs.count > 0
                    {
                        let peri : CBPeripheral = devs[0]
                        
                        self.centralManager(central,  didDiscover:peri,  advertisementData:["Hello" : "Hello"],  rssi:NSNumber())
                        return;
                    }
                }
            }
            
            
        }
        
        
        self.discoveredPeripheral = nil;
    }
    
    //MARK: - CBPeripheralDelegate
    
    open func peripheral(_ peripheral: CBPeripheral,
        didDiscoverServices error: Error?)
    {
        
        
        if let serv = peripheral.services{
            for sr in serv
            {
                NSLog("Service %@", sr.uuid.uuidString)
                
                if sr.uuid.uuidString == TMKHeartRateMonitor.kUUIDHeartRateService
                {
                    let charUUIDs = [CBUUID(string:TMKHeartRateMonitor.kUUIDHeartRateVariable)]
                    peripheral.discoverCharacteristics(charUUIDs, for:sr)
                }
                    
                else if sr.uuid.uuidString == TMKHeartRateMonitor.kUUIDBatteryLevelService
                {
                    let charUUIDs = [CBUUID(string:TMKHeartRateMonitor.kUUIDBatteryLevelVariable)]
                    peripheral.discoverCharacteristics(charUUIDs, for:sr)
                }
                else if sr.uuid.uuidString == TMKHeartRateMonitor.kUUIDMioLinkHRZonesService
                {
                    let charUUIDs = [CBUUID(string:TMKHeartRateMonitor.kUUIDMioLinkHRZonesVariable)]
                    peripheral.discoverCharacteristics(charUUIDs, for:sr)
                }
                else if sr.uuid.uuidString == TMKHeartRateMonitor.kUUIDDeviceInfoService{
                    
                    let charUUIDs = [CBUUID(string:TMKHeartRateMonitor.kUUIDManufacturerNameVariable),
                        CBUUID(string:TMKHeartRateMonitor.kUUIDModelNameVariable),
                        CBUUID(string:TMKHeartRateMonitor.kUUIDSerialNumberVariable),
                        CBUUID(string:TMKHeartRateMonitor.kUUIDHardwareVersion),
                        CBUUID(string:TMKHeartRateMonitor.kUUIDFirmwareVersion),
                        CBUUID(string:TMKHeartRateMonitor.kUUIDSoftwareVersion)]
                    
                    peripheral.discoverCharacteristics(charUUIDs, for:sr)
                    
                }
            }
        }
        
    }
    
    
    open func peripheral(_ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?)
    {
        
        // Sembla una bona conexio, la guardem per mes endavant
        let store = UserDefaults.standard
        let idPeripheral = peripheral.identifier.uuidString
        
        store.set(idPeripheral, forKey:TMKHeartRateMonitor.kLastHRDeviceAccessedKey)
        
        if let characteristics = service.characteristics {
            for ch in characteristics {
                
                if ch.uuid.uuidString == TMKHeartRateMonitor.kUUIDHeartRateVariable
                {
                    peripheral.setNotifyValue(true, for:ch)
                    self.sendNotification(TMKHeartRateMonitor.kSubscribedToHRStartedNotification, object:peripheral)
                    self.connected = true
                }
                else{
                    peripheral.readValue(for: ch)
                }
                
            }
        }
        
    }
    
    open func peripheral(_ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?){
            
            // Primer obtenim el TMKPeripheralObject
            
            if characteristic.uuid.uuidString == TMKHeartRateMonitor.kUUIDHeartRateVariable  // HR
            {
                
                
                
                let siz = characteristic.value!.count
                
                var nrr = (siz - 2) / 2
                
                if nrr > 12{
                    nrr = 12
                }
                
                var dades = hrdata(flags: 0, hr: 0, rr0:0, rr1:0, rr2:0, rr3:0, rr4:0, rr5:0, rr6:0, rr7:0, rr8:0, rr9:0)
                
                (characteristic.value! as NSData).getBytes(&dades, length: siz)
                
                let value = dades.hr
                //UInt8   flags = dades ->flags;
                
                self.hr = Int(value)
                
                /* El codi a continuacio permet accedir als valors de RR
                Com que no els fem servir, simplement ho ignorem.*/
                
                // Longitut total de ls dades rebudes
                // NSUInteger nRR = (len-2)/2; // Calula el numero de elements RR que tenim. Cada u es un uint16
                
                // COMPTE el rr es base 1024. Per convertir-ho a segons es rr/1024.
                
                // Valen fins que son 0.
                
               //  NSLog("HR %d - rr %d %d %d %d", value, dades.rr0, dades.rr1, dades.rr2, dades.rr3);
                
                
                
                
                // Create a HealthKit value
                
                let qt = HKQuantity(unit: TMKHeartRateMonitor.kBeatsPerMinute, doubleValue: Double(value))
                
                var sample : HKQuantitySample?
                
                if #available(iOS 9.0, *) {
                    
                    let idPeripheral = peripheral.identifier.uuidString
                    
                    let device = HKDevice(name: peripheral.name, manufacturer: self.manufacturer, model: self.model, hardwareVersion: self.hardwareVer, firmwareVersion: self.firmwareVer, softwareVersion: self.softwareVer, localIdentifier: "", udiDeviceIdentifier: idPeripheral)
                    
                    
                    sample = HKQuantitySample(type: TMKHeartRateMonitor.kHeartRateType!, quantity: qt, start: Date(), end: Date(), device: device, metadata: nil)
                    
                } else {
                    sample = HKQuantitySample(type:TMKHeartRateMonitor.kHeartRateType!, quantity: qt, start: Date(), end: Date())
                }
                
                
                self.sendNotification(TMKHeartRateMonitor.kHRReceivedNotification, object:sample)
            }
                
            else if characteristic.uuid.uuidString==TMKHeartRateMonitor.kUUIDBatteryLevelVariable  // Battery
            {
                
                var dades = battData(value: 0)
                (characteristic.value! as NSData).getBytes(&dades, length: 1)
                
                self.battery = Int(dades.value)
                
                self.sendNotification(TMKHeartRateMonitor.kBatteryReceivedNotification, object:self.battery as AnyObject?)
                
            }
            else if characteristic.uuid.uuidString==TMKHeartRateMonitor.kUUIDManufacturerNameVariable  {
                
                if let data = characteristic.value {
                    self.manufacturer = String(data:data, encoding: String.Encoding.utf8)
                }
            }
            else if characteristic.uuid.uuidString==TMKHeartRateMonitor.kUUIDModelNameVariable  {
                
                if let data = characteristic.value {
                    self.model = String(data:data, encoding: String.Encoding.utf8)
                }
            }
            else if characteristic.uuid.uuidString==TMKHeartRateMonitor.kUUIDSerialNumberVariable  {
                
                if let data = characteristic.value {
                    self.serial = String(data:data, encoding: String.Encoding.utf8)
                }
            }
            else if characteristic.uuid.uuidString==TMKHeartRateMonitor.kUUIDHardwareVersion  {
                
                if let data = characteristic.value {
                    self.hardwareVer = String(data:data, encoding: String.Encoding.utf8)
                }
            }
            else if characteristic.uuid.uuidString==TMKHeartRateMonitor.kUUIDFirmwareVersion  {
                
                if let data = characteristic.value {
                    self.firmwareVer = String(data:data, encoding: String.Encoding.utf8)
                }
            }
            else if characteristic.uuid.uuidString==TMKHeartRateMonitor.kUUIDSoftwareVersion {
                
                if let data = characteristic.value {
                    self.softwareVer = String(data:data, encoding: String.Encoding.utf8)
                }
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
    
    func sendNotification(_ not:String, object: AnyObject?)
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
        let notification = Notification(name:Notification.Name(rawValue: not), object:object)
        NotificationCenter.default.post(notification)
    }
    
    
    
    open func cleanup() {
        
        // See if we are subscribed to a characteristic on the peripheral
        
        if let thePeripheral = self.discoveredPeripheral  {
            if let theServices = thePeripheral.services {
                
                for service : CBService in theServices {
                    
                    if let theCharacteristics = service.characteristics {
                        for characteristic : CBCharacteristic in theCharacteristics {
                            if characteristic.uuid == CBUUID(string:"2A67") {
                                if characteristic.isNotifying {
                                    self.discoveredPeripheral!.setNotifyValue(false, for:characteristic)
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
