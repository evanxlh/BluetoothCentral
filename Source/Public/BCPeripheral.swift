//
//  BCPeripheral.swift
//  BluetoothCentral
//
//  Created by Evan Xie on 2020/6/2.
//

import Foundation
import CoreBluetooth

public protocol BCPeripheralDelegate: AnyObject {
    
    /// 已准备好蓝牙服务，可以跟蓝牙设备通信了
    func peripheralServiceDidReady(_ peripheral: BCPeripheral)
    
    /// 从 `CBCharacteristic` 接收到数据, 用`characteristicUUID` 来区分不同的 `CBCharacteristic`
    func peripheralDidRecevieCharacteristicData(_ peripheral: BCPeripheral, data: Data, characteristicUUID: String)
}

public class BCPeripheral: NSObject {
    
    fileprivate let peripheral: CBPeripheral
    fileprivate let deleteProxy: PeripheralDelegateProxy
    fileprivate var serviceFilters = [BCDiscoverServiceFilter]()
    
    fileprivate var dataChannelsMap = [String: SendDataChannel]()
    fileprivate var characteristicsMap = [String: CBCharacteristic]()
    
    public weak var delegate: BCPeripheralDelegate?
    
    public init(peripheral: CBPeripheral) {
        self.deleteProxy = PeripheralDelegateProxy()
        self.peripheral = peripheral
        super.init()
        self.deleteProxy.delegate = self
        self.peripheral.delegate = deleteProxy
    }
    
    /// 根据过滤条件查找 service & characteristics
    /// - Parameter filters: 默认为空，即查找所有的 service, characteristics
    public func discoverService(_ filters: [BCDiscoverServiceFilter] = []) {
        clean()
        serviceFilters = filters
        peripheral.discoverServices(BCDiscoverServiceFilter.serviceCBUUIDs(from: filters))
    }
    
    public func sendData(_ data: Data, toCharacteristicByUUID characteristicUUID : String) {
        guard let dataChannel = dataChannel(by: characteristicUUID) else {
            return
        }
        dataChannel.sendData(data)
    }
    
}

fileprivate extension BCPeripheral {
    
    func dataChannel(by characteristicUUID: String) -> SendDataChannel? {
        return dataChannelsMap[characteristicUUID]
    }
    
    func clean() {
        dataChannelsMap.values.forEach {
            $0.cancelAllSendDataTasks()
        }
        characteristicsMap.removeAll()
        dataChannelsMap.removeAll()
        characteristicsMap.removeAll()
    }
}

extension BCPeripheral: PeripheralDelegate {
    
    func peripheralIsReadyToSendData(_ peripheral: CBPeripheral) {
        dataChannelsMap.values.forEach {
            $0.peripheralIsReadyToSendData()
        }
    }
    
    func peripheralDidDiscoverServices(_ peripheral: CBPeripheral) {
        
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
            let characteristicUUIDs = BCDiscoverServiceFilter.characteristicCBUUIDs(from: serviceFilters, forService: service)
            peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didFailToDiscoverServices error: Error) {
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService) {
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            let uuidString = characteristic.uuid.uuidString
            let properties = characteristic.properties
            self.characteristicsMap[uuidString] = characteristic
            
            if properties.contains(.write) || properties.contains(.writeWithoutResponse) {
                // 为 CBCharacteristic 创建数据发送通道
                let dataChannel = SendDataChannel(peripheral: peripheral, characteristic: characteristic)
                dataChannelsMap[characteristic.uuid.uuidString] = dataChannel
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didFailToDiscoverCharacteristicsForService service: CBService, error: Error) {
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic) {
        guard let data = characteristic.value, data.count > 0 else { return }
        print("characteristic: \(characteristic.uuid.uuidString)\n   -> data: \(data)")
        delegate?.peripheralDidRecevieCharacteristicData(self, data: data, characteristicUUID: characteristic.uuid.uuidString)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didFailToUpdateValueForCharacteristic characteristic: CBCharacteristic, error: Error) {
        
    }
    
}
