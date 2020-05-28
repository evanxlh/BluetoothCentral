//
//  UnifiedManagerState.swift
//
//  Created by Evan Xie on 2/25/20.
//

import Foundation
import CoreBluetooth

///  统一蓝牙状态(`CBCentralManagerState` 和 `CBManagerState`)，不用再为 iOS 不同版本 API 的差异而分心。
internal enum UnifiedManagerState: Int {
    
    /// 蓝牙已打开，可以正常使用
    case poweredOn
    
    /// 蓝牙已关闭
    case poweredOff
    
    /// 蓝牙正在重置
    case resetting
    
    /// App 未被授权蓝牙访问
    case unauthorized
    
    /// 此设备上不支持 Bluetooth LE
    case unsupported
    
    /// 未知的临时状态，Core Bluetooth 初始化完成，或重置后，此状态会被更新。
    case unknown
}

extension CBCentralManager {
    
    /// 不管是 `CBCentralManagerState`, 还是 `CBManagerState`, 统一成一个状态。
    internal var unifiedState: UnifiedManagerState {
        switch state {
        case .poweredOn:
            return .poweredOn
        case .poweredOff:
            return .poweredOff
        case .resetting:
            return .resetting
        case .unauthorized:
            return .unauthorized
        case .unsupported:
            return .unsupported
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}
