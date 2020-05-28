//
//  Logger.swift
//
//  Created by Evan Xie on 2019/3/29.
//

import Foundation

internal struct Logger {
    
    static var isEnabled = true
    
    private static var _dateFormatter: DateFormatter? = nil
    
    private static var dateFormatter: DateFormatter {
        if _dateFormatter == nil {
            _dateFormatter = DateFormatter()
            _dateFormatter?.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        }
        return _dateFormatter!
    }
    
    static func trace(file: String = #file, method: String = #function) {
        if isEnabled {
            print("[Trace] \(dateFormatter.string(from: Date())) \(method)]")
        }
    }
    
    static func debug<T>(_ message: T, file: String = #file, method: String = #function) {
        if isEnabled {
            print("[Debug] \(dateFormatter.string(from: Date())) \(message)")
        }
    }
    
    
    
    static func info<T>(_ message: T, file: String = #file, method: String = #function) {
        if isEnabled {
            print("[Info] \(dateFormatter.string(from: Date())) \(message)")
        }
    }
    
    static func warning<T>(_ message: T, file: String = #file, method: String = #function) {
        if isEnabled {
            print("⚠️ \(dateFormatter.string(from: Date())) \(message)")
        }
    }
    
    static func error<T>(_ message: T, file: String = #file, method: String = #function) {
        if isEnabled {
            print("❌ \(dateFormatter.string(from: Date())) \(message)")
        }
    }
    
    static func tag<T>(_ tag: String, message: T, file: String = #file, method: String = #function) {
        if isEnabled {
            print("[\(tag)] \(dateFormatter.string(from: Date())) \(message)")
        }
    }
}
