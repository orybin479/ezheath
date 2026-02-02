//
//  SettingsViewModel.swift
//  EZHeath
//
//  Created by Oleg Rybin on 2/1/26.
//

import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled = true
    @Published var darkModeEnabled = false
    @Published var ringDeviceName = "2301B 00092"
    @Published var ringBatteryLevel = 74
    @Published var ringFirmwareVersion = "0.7.0.7"
    @Published var ringIsConnected = false
    
    @Published var scaleDeviceName = "Scale 00045"
    @Published var scaleBatteryLevel = 100
    @Published var scaleFirmwareVersion = "1.2.3"
    @Published var scaleIsConnected = false
    
    @Published var appVersion = "1.10.17"
    @Published var userName = "Oleg"
    
    // MARK: - Device Management
    
    func unpairDevices() {
        ringIsConnected = false
        scaleIsConnected = false
        print("🔓 Devices unpaired")
    }
    
    func updateRingDeviceName(_ name: String) {
        ringDeviceName = name
    }
    
    func updateScaleDeviceName(_ name: String) {
        scaleDeviceName = name
    }
    
    func refreshDeviceStatus() {
        // TODO: Implement actual device status check
        print("🔄 Refreshing device status...")
    }
}

class DataSharingViewModel: ObservableObject {
    @Published var healthRecords: [RingData] = []
    @Published var showingDeleteAlert = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let databaseManager = DatabaseManager.shared
    
    // MARK: - Data Loading
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let records = self?.databaseManager.getAllHealthData(limit: 100) ?? []
            
            DispatchQueue.main.async {
                self?.healthRecords = records
                self?.isLoading = false
                print("✅ Loaded \(records.count) health records")
            }
        }
    }
    
    func deleteAllData() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.databaseManager.deleteAllData()
            
            DispatchQueue.main.async {
                self?.healthRecords = []
                self?.isLoading = false
                print("🗑️ All health data deleted")
            }
        }
    }
    
    func exportData() {
        // TODO: Implement data export to CSV or JSON
        print("📤 Exporting data...")
    }
    
    // MARK: - Computed Properties
    
    var totalRecordsCount: Int {
        healthRecords.count
    }
    
    var latestRecord: RingData? {
        healthRecords.first
    }
    
    var hasData: Bool {
        !healthRecords.isEmpty
    }
}

class DeviceSettingsViewModel: ObservableObject {
    @Published var autoSyncEnabled = true
    @Published var syncInterval = 15 // minutes
    @Published var batteryOptimizationEnabled = true
    @Published var dataCompressionEnabled = false
    
    func saveSettings() {
        print("💾 Saving device settings...")
        // TODO: Implement actual settings persistence
    }
}

class GeneralSettingsViewModel: ObservableObject {
    @Published var notificationsEnabled = true
    @Published var healthRemindersEnabled = true
    @Published var dailySummaryTime = Date()
    @Published var useMetricUnits = false
    @Published var darkModeEnabled = false
    @Published var hapticFeedbackEnabled = true
    
    func saveSettings() {
        print("💾 Saving general settings...")
        // TODO: Implement actual settings persistence
    }
    
    func resetToDefaults() {
        notificationsEnabled = true
        healthRemindersEnabled = true
        useMetricUnits = false
        darkModeEnabled = false
        hapticFeedbackEnabled = true
        print("🔄 Settings reset to defaults")
    }
}
