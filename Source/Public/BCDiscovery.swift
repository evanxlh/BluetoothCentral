//
//  BCDiscovery.swift
//
//  Created by Evan Xie on 2/21/20.
//

import Foundation
import CoreBluetooth

/// 扫描发现的蓝牙设备信息
public struct BCDiscovery: Equatable {
    
    public let advertisementData: [String: Any]
    public let peripheral: CBPeripheral
    public let rssi: Int
    
    public var localName: String? {
        return advertisementData[CBAdvertisementDataLocalNameKey] as? String
    }
    
    public init(advertisementData: [String: Any], peripheral: CBPeripheral, rssi: Int) {
        self.advertisementData = advertisementData
        self.peripheral = peripheral
        self.rssi = rssi
    }

    public static func == (lhs: BCDiscovery, rhs: BCDiscovery) -> Bool {
        return lhs.peripheral == rhs.peripheral
    }
}
