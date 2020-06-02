//
//  BCDiscoverServiceFilter.swift
//
//  Created by Evan Xie on 2020/6/2.
//

import Foundation
import CoreBluetooth

public struct BCDiscoverServiceFilter {
    public let serviceUUID: String
    public let characteristicUUIDs: [String]
    
    
    /// `characteristicUUIDs` 默认为空，即查找此 `service` 所有的 `characteristics`。
    public init(serviceUUID: String, characteristicUUIDs: [String] = []) {
        self.serviceUUID = serviceUUID
        self.characteristicUUIDs = characteristicUUIDs
    }
}

internal extension BCDiscoverServiceFilter {
    
    static func serviceCBUUIDs(from filters: [BCDiscoverServiceFilter]) -> [CBUUID]? {
        if filters.count == 0 {  return nil }
        return filters.map { CBUUID(string: $0.serviceUUID) }
    }
    
    static func characteristicCBUUIDs(from filters: [BCDiscoverServiceFilter], forService service: CBService) -> [CBUUID]? {
        if filters.count == 0 {  return nil }
        guard let filter = filters.filter({ $0.serviceUUID == service.uuid.uuidString }).first else { return nil }
       
        if filter.characteristicUUIDs.count == 0 { return nil }
        return filter.characteristicUUIDs.map { CBUUID(string: $0) }
    }
    
    func toCBServiceUUID() -> CBUUID {
        return CBUUID(string: serviceUUID)
    }
    
    func toCBCharacteristicUUIDs() -> [CBUUID]? {
        if characteristicUUIDs.count == 0 { return nil }
        return characteristicUUIDs.map { CBUUID(string: $0) }
    }
    
    func containsService(_ service: CBService) -> Bool {
        return serviceUUID == service.uuid.uuidString
    }
    
    func containsCharacteristic(_ characteristic: CBCharacteristic) -> Bool {
        return characteristicUUIDs.contains(characteristic.uuid.uuidString)
    }
}
