//
//  PeripheralDelegateProxy.swift
//
//  Created by Evan Xie on 2020/6/2.
//

import Foundation
import CoreBluetooth

internal protocol InternalPeripheralDelegate: AnyObject {
    
    func peripheralIsReadyToSendData(_ peripheral: CBPeripheral)
    func peripheralDidDiscoverServices(_ peripheral: CBPeripheral)
    func peripheral(_ peripheral: CBPeripheral, didFailToDiscoverServices error: Error)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService)
    func peripheral(_ peripheral: CBPeripheral, didFailToDiscoverCharacteristicsForService service: CBService, error: Error)
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic)
    func peripheral(_ peripheral: CBPeripheral, didFailToUpdateValueForCharacteristic characteristic: CBCharacteristic, error: Error)
}

internal final class PeripheralDelegateProxy: NSObject, CBPeripheralDelegate {
    
    weak var delegate: InternalPeripheralDelegate?
    
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        Logger.tag("Peripheral", message: "peripheralIsReady toSendWriteWithoutResponse")
        delegate?.peripheralIsReadyToSendData(peripheral)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error == nil {
            delegate?.peripheralDidDiscoverServices(peripheral)
        } else {
            delegate?.peripheral(peripheral, didFailToDiscoverServices: error!)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error == nil {
            delegate?.peripheral(peripheral, didDiscoverCharacteristicsForService: service)
        } else {
            delegate?.peripheral(peripheral, didFailToDiscoverCharacteristicsForService: service, error: error!)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil {
            delegate?.peripheral(peripheral, didUpdateValueForCharacteristic: characteristic)
        } else {
            delegate?.peripheral(peripheral, didFailToUpdateValueForCharacteristic: characteristic, error: error!)
        }
    }
    
    // MARK: - 不常用，，暂不实现
    
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        Logger.tag("Peripheral", message: "peripheralDidUpdateName: \(String(describing: peripheral.name))")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        Logger.tag("Peripheral", message: "didReadRSSI: \(RSSI)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let message: String?
        if let data = characteristic.value {
            message = String(data: data, encoding: .utf8)
        } else {
            message = nil
        }
        Logger.tag("Peripheral", message: "didWriteValue: [\(String(describing: message))], forCharacteristic: \(characteristic.uuid.uuidString), error: \(String(describing: error))")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Logger.tag("Peripheral", message: "didUpdateNotificationStateForCharacteristic: \(characteristic.uuid.uuidString), error: \(String(describing: error))")
    }
    
    // MARK: - 极少用，暂不实现
    func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        
    }
    
    @available(iOS 11.0, *)
    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        
    }

}
