//
//  PeripheralDiscovery.swift
//
//  Created by Evan Xie on 2/21/20.
//

import Foundation
import CoreBluetooth

/// 扫描发现的蓝牙设备信息
public struct PeripheralDiscovery: Equatable {
    
    public let advertisementData: [String: Any]
    public let peripheral: Peripheral
    public let rssi: Int
    
    public var localName: String? {
        return advertisementData[CBAdvertisementDataLocalNameKey] as? String
    }
    
    internal init(advertisementData: [String: Any], peripheral: Peripheral, rssi: NSNumber) {
        self.advertisementData = advertisementData
        self.peripheral = peripheral
        self.rssi = rssi.intValue
    }

    public static func == (lhs: PeripheralDiscovery, rhs: PeripheralDiscovery) -> Bool {
        return lhs.peripheral.identifier == rhs.peripheral.identifier
    }
}
