//
//  DatabaseManager.swift
//  EZHeath
//
//  Created by Oleg Rybin on 2/1/26.
//

import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    init() {
        // Get the path to the Documents directory
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dbPath = documentsPath.appendingPathComponent("health_data.sqlite").path
        
        print("📁 Database path: \(dbPath)")
        
        openDatabase()
        createTables()
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Connection
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ Error opening database")
            return
        }
        print("✅ Successfully opened database")
    }
    
    private func closeDatabase() {
        if sqlite3_close(db) != SQLITE_OK {
            print("❌ Error closing database")
        } else {
            print("✅ Successfully closed database")
        }
    }
    
    // MARK: - Table Creation
    
    private func createTables() {
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS health_metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            heart_rate INTEGER,
            spo2 INTEGER,
            steps INTEGER,
            hrv INTEGER,
            calories INTEGER,
            stress INTEGER,
            sleep_hours REAL,
            blood_glucose INTEGER,
            temperature REAL,
            vo2_max INTEGER,
            timestamp TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        """
        
        var createTableStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableQuery, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("✅ Health metrics table created successfully")
            } else {
                print("❌ Health metrics table could not be created")
            }
        } else {
            print("❌ CREATE TABLE statement could not be prepared")
        }
        
        sqlite3_finalize(createTableStatement)
    }
    
    // MARK: - Insert Data
    
    func saveHealthData(_ data: RingData) {
        let insertQuery = """
        INSERT INTO health_metrics (
            heart_rate, spo2, steps, hrv, calories, stress,
            sleep_hours, blood_glucose, temperature, vo2_max, timestamp
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var insertStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &insertStatement, nil) == SQLITE_OK {
            // Bind values
            bindInt(insertStatement, index: 1, value: data.heartRate)
            bindInt(insertStatement, index: 2, value: data.spO2)
            bindInt(insertStatement, index: 3, value: data.steps)
            bindInt(insertStatement, index: 4, value: data.hrv)
            bindInt(insertStatement, index: 5, value: data.calories)
            bindInt(insertStatement, index: 6, value: data.stress)
            bindDouble(insertStatement, index: 7, value: data.sleepHours)
            bindInt(insertStatement, index: 8, value: data.bloodGlucose)
            bindDouble(insertStatement, index: 9, value: data.temperature)
            bindInt(insertStatement, index: 10, value: data.vo2Max)
            
            // Timestamp
            let dateFormatter = ISO8601DateFormatter()
            let timestampString = dateFormatter.string(from: data.timestamp)
            sqlite3_bind_text(insertStatement, 11, (timestampString as NSString).utf8String, -1, nil)
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("✅ Successfully saved health data to database")
            } else {
                print("❌ Could not save health data")
            }
        } else {
            print("❌ INSERT statement could not be prepared")
        }
        
        sqlite3_finalize(insertStatement)
    }
    
    // MARK: - Query Data
    
    func getLatestHealthData() -> RingData? {
        let query = """
        SELECT heart_rate, spo2, steps, hrv, calories, stress,
               sleep_hours, blood_glucose, temperature, vo2_max, timestamp
        FROM health_metrics
        ORDER BY created_at DESC
        LIMIT 1;
        """
        
        var queryStatement: OpaquePointer?
        var result: RingData?
        
        if sqlite3_prepare_v2(db, query, -1, &queryStatement, nil) == SQLITE_OK {
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                result = RingData(
                    heartRate: getInt(queryStatement, column: 0),
                    steps: getInt(queryStatement, column: 2),
                    calories: getInt(queryStatement, column: 4),
                    sleepHours: getDouble(queryStatement, column: 6),
                    spO2: getInt(queryStatement, column: 1),
                    hrv: getInt(queryStatement, column: 3),
                    stress: getInt(queryStatement, column: 5),
                    bloodGlucose: getInt(queryStatement, column: 7),
                    temperature: getDouble(queryStatement, column: 8),
                    vo2Max: getInt(queryStatement, column: 9)
                )
                print("✅ Retrieved latest health data from database")
            }
        } else {
            print("❌ SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(queryStatement)
        return result
    }
    
    func getAllHealthData(limit: Int = 100) -> [RingData] {
        let query = """
        SELECT heart_rate, spo2, steps, hrv, calories, stress,
               sleep_hours, blood_glucose, temperature, vo2_max, timestamp
        FROM health_metrics
        ORDER BY created_at DESC
        LIMIT ?;
        """
        
        var queryStatement: OpaquePointer?
        var results: [RingData] = []
        
        if sqlite3_prepare_v2(db, query, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(queryStatement, 1, Int32(limit))
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let data = RingData(
                    heartRate: getInt(queryStatement, column: 0),
                    steps: getInt(queryStatement, column: 2),
                    calories: getInt(queryStatement, column: 4),
                    sleepHours: getDouble(queryStatement, column: 6),
                    spO2: getInt(queryStatement, column: 1),
                    hrv: getInt(queryStatement, column: 3),
                    stress: getInt(queryStatement, column: 5),
                    bloodGlucose: getInt(queryStatement, column: 7),
                    temperature: getDouble(queryStatement, column: 8),
                    vo2Max: getInt(queryStatement, column: 9)
                )
                results.append(data)
            }
            print("✅ Retrieved \(results.count) health records from database")
        } else {
            print("❌ SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(queryStatement)
        return results
    }
    
    func getHealthDataForDateRange(startDate: Date, endDate: Date) -> [RingData] {
        let query = """
        SELECT heart_rate, spo2, steps, hrv, calories, stress,
               sleep_hours, blood_glucose, temperature, vo2_max, timestamp
        FROM health_metrics
        WHERE timestamp BETWEEN ? AND ?
        ORDER BY created_at DESC;
        """
        
        var queryStatement: OpaquePointer?
        var results: [RingData] = []
        
        let dateFormatter = ISO8601DateFormatter()
        
        if sqlite3_prepare_v2(db, query, -1, &queryStatement, nil) == SQLITE_OK {
            let startString = dateFormatter.string(from: startDate)
            let endString = dateFormatter.string(from: endDate)
            
            sqlite3_bind_text(queryStatement, 1, (startString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 2, (endString as NSString).utf8String, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let data = RingData(
                    heartRate: getInt(queryStatement, column: 0),
                    steps: getInt(queryStatement, column: 2),
                    calories: getInt(queryStatement, column: 4),
                    sleepHours: getDouble(queryStatement, column: 6),
                    spO2: getInt(queryStatement, column: 1),
                    hrv: getInt(queryStatement, column: 3),
                    stress: getInt(queryStatement, column: 5),
                    bloodGlucose: getInt(queryStatement, column: 7),
                    temperature: getDouble(queryStatement, column: 8),
                    vo2Max: getInt(queryStatement, column: 9)
                )
                results.append(data)
            }
            print("✅ Retrieved \(results.count) health records for date range")
        }
        
        sqlite3_finalize(queryStatement)
        return results
    }
    
    // MARK: - Delete Data
    
    func deleteAllData() {
        let deleteQuery = "DELETE FROM health_metrics;"
        var deleteStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteQuery, -1, &deleteStatement, nil) == SQLITE_OK {
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                print("✅ All health data deleted successfully")
            } else {
                print("❌ Could not delete health data")
            }
        }
        
        sqlite3_finalize(deleteStatement)
    }
    
    // MARK: - Helper Functions
    
    private func bindInt(_ statement: OpaquePointer?, index: Int32, value: Int?) {
        if let value = value {
            sqlite3_bind_int(statement, index, Int32(value))
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    private func bindDouble(_ statement: OpaquePointer?, index: Int32, value: Double?) {
        if let value = value {
            sqlite3_bind_double(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    private func getInt(_ statement: OpaquePointer?, column: Int32) -> Int? {
        if sqlite3_column_type(statement, column) == SQLITE_NULL {
            return nil
        }
        return Int(sqlite3_column_int(statement, column))
    }
    
    private func getDouble(_ statement: OpaquePointer?, column: Int32) -> Double? {
        if sqlite3_column_type(statement, column) == SQLITE_NULL {
            return nil
        }
        return sqlite3_column_double(statement, column)
    }
}
