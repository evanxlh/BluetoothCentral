//
//  ServiceInfo.swift
//  BluetoothCentral
//
//  Created by Evan Xie on 2020/6/9.
//

import Foundation
import CoreBluetooth


/// 描述蓝牙设备的单个 `GATT Service` 信息。参考：
/// [GATT](https://learn.adafruit.com/introduction-to-bluetooth-low-energy/gatt)，
/// [Services and Characteristics](https://www.oreilly.com/library/view/getting-started-with/9781491900550/ch04.html)，
/// [Normative Services](https://www.bluetooth.com/specifications/gatt/services/)。
public struct ServiceInfo: Equatable {
    
    public let uuid: String
    public let isPrimary: Bool
    
    /// UUID 与 ServiceInfo 键值对
    public var characteristicInfos: [String: CharacteristicInfo] {
        return _characteristicInfos
    }
    
    internal var _characteristicInfos = [String: CharacteristicInfo]()
    
    internal init(uuid: String, isPrimary: Bool) {
        self.uuid = uuid
        self.isPrimary = isPrimary
    }
    
    public static func == (lhs: ServiceInfo, rhs: ServiceInfo) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

/// 描述蓝牙设备的单个 `GATT Characteristic` 信息。参考：
/// [GATT](https://learn.adafruit.com/introduction-to-bluetooth-low-energy/gatt)，
/// [Services and Characteristics](https://www.oreilly.com/library/view/getting-started-with/9781491900550/ch04.html)。
public struct CharacteristicInfo: Equatable {
    
    public enum WriteBehavior: Int {
        case writeWithResponse
        case writeWithoutResponse
        case unsupported
    }
    
    public let uuid: String
    public let properties: CBCharacteristicProperties
    
    public var isReadable: Bool {
        return properties.contains(.read)
    }
    
    public var isWritable: Bool {
        return properties.contains(.write) || properties.contains(.writeWithoutResponse)
    }
    
    public var writeBehavior: WriteBehavior {
        if properties.contains(.write) {
            return .writeWithResponse
        } else if properties.contains(.writeWithoutResponse) {
            return .writeWithoutResponse
        } else {
            return .unsupported
        }
    }
    
    internal init(uuid: String, properties: CBCharacteristicProperties) {
        self.uuid = uuid
        self.properties = properties
    }
    
    public static func == (lhs: CharacteristicInfo, rhs: CharacteristicInfo) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
