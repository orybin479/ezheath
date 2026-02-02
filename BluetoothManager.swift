//
//  BluetoothManager.swift
//  EZHeath
//
//  Created by Oleg Rybin on 2/1/26.
//

import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject {
    @Published var isSyncing = false
    @Published var isConnected = false
    @Published var syncedData: RingData?
    @Published var discoveredDevices: [(name: String, peripheral: CBPeripheral)] = []
    
    var centralManager: CBCentralManager?
    private var ringPeripheral: CBPeripheral?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Load latest data from database
        syncedData = DatabaseManager.shared.getLatestHealthData()
        if syncedData != nil {
            print("✅ Loaded latest health data from database")
        }
    }
    
    func syncRingData() {
        guard !isSyncing else { return }
        
        isSyncing = true
        discoveredDevices = []
        
        // Start scanning for the ring device
        if let centralManager = centralManager, centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            
            // Timeout after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                self?.stopScanning()
            }
        } else {
            // Bluetooth not available
            isSyncing = false
            print("Bluetooth is not available")
        }
    }
    
    func startDiscovery() {
        discoveredDevices = []
        if let centralManager = centralManager, centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func connectToDevice(_ peripheral: CBPeripheral) {
        print("Attempting to connect to device: \(peripheral.name ?? "Unknown")")
        centralManager?.stopScan()
        ringPeripheral = peripheral
        ringPeripheral?.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }
    
    private func stopScanning() {
        centralManager?.stopScan()
        if ringPeripheral == nil {
            isSyncing = false
            print("Ring device not found")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
            isSyncing = false
        case .unauthorized:
            print("Bluetooth access is unauthorized")
            isSyncing = false
        case .unsupported:
            print("Bluetooth is not supported on this device")
            isSyncing = false
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Add all discovered devices to the list
        if let name = peripheral.name, !name.isEmpty {
            // Check if device is already in the list
            if !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
                discoveredDevices.append((name: name, peripheral: peripheral))
                print("✅ Discovered device: \(name) | RSSI: \(RSSI)")
            }
        }
        
        // Auto-connect to ring devices during sync
        if isSyncing {
            if let name = peripheral.name, 
               name.contains("Ring") || 
               name.contains("Health") || 
               name.contains("EZ") || 
               name.contains("JC") ||
               name.uppercased().contains("RING") {
                print("🎯 Found potential ring device: \(name)")
                ringPeripheral = peripheral
                ringPeripheral?.delegate = self
                central.stopScan()
                central.connect(peripheral, options: nil)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to ring device")
        isConnected = true
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from ring device")
        isConnected = false
        isSyncing = false
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to ring device: \(error?.localizedDescription ?? "Unknown error")")
        isSyncing = false
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            isSyncing = false
            return
        }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            isSyncing = false
            return
        }
        
        for characteristic in characteristics {
            // Read data from characteristics
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            
            // Subscribe to notifications if available
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        // Parse the data from your ring
        // This will depend on your ring's data format
        parseRingData(data)
        
        isSyncing = false
    }
    
    private func parseRingData(_ data: Data) {
        // TODO: Parse the actual data format from your ring
        // This is a placeholder implementation
        print("Received data: \(data)")
        
        // Example: Create RingData from received data
        // For now, let's create sample data for testing
        let parsedData = RingData(
            heartRate: 75,
            steps: 5000,
            calories: 250,
            sleepHours: 7.5,
            spO2: 98,
            hrv: 55,
            stress: 45,
            bloodGlucose: 95,
            temperature: 98.6,
            vo2Max: 42
        )
        
        // Save to database
        DatabaseManager.shared.saveHealthData(parsedData)
        
        // Update the published property
        syncedData = parsedData
    }
}

// MARK: - Data Model
struct RingData {
    var heartRate: Int?
    var steps: Int?
    var calories: Int?
    var sleepHours: Double?
    var spO2: Int?
    var hrv: Int?
    var stress: Int?
    var bloodGlucose: Int?
    var temperature: Double?
    var vo2Max: Int?
    var timestamp: Date
    
    init(
        heartRate: Int? = nil,
        steps: Int? = nil,
        calories: Int? = nil,
        sleepHours: Double? = nil,
        spO2: Int? = nil,
        hrv: Int? = nil,
        stress: Int? = nil,
        bloodGlucose: Int? = nil,
        temperature: Double? = nil,
        vo2Max: Int? = nil
    ) {
        self.heartRate = heartRate
        self.steps = steps
        self.calories = calories
        self.sleepHours = sleepHours
        self.spO2 = spO2
        self.hrv = hrv
        self.stress = stress
        self.bloodGlucose = bloodGlucose
        self.temperature = temperature
        self.vo2Max = vo2Max
        self.timestamp = Date()
    }
}
