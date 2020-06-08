//
//  Peripheral.swift
//
//  Created by Evan Xie on 2020/6/2.
//

import Foundation
import CoreBluetooth

public protocol PeripheralDelegate: AnyObject {
    
    /// 已准备好蓝牙服务，可以跟蓝牙设备通信了
    func peripheralServiceDidReady(_ peripheral: Peripheral)
}

public protocol PeripheralReceiveDataDelegate: AnyObject {
    
    /// 从 `CBCharacteristic` 接收到数据, 用`characteristicUUID` 来区分不同的 `CBCharacteristic`
    func peripheralDidRecevieCharacteristicData(_ peripheral: Peripheral, data: Data, characteristicUUID: String)
}

public class Peripheral: NSObject {
    
    public enum DataChannelState {
        case notStarted
        case starting
        case ready
        case error(Error)
    }
    
    public enum NoConnectionReason: Int {
        case connecting
        case disconnecting
        case disconnected
    }
    
    public enum DataChannelError: Error {
        case unavailable(reason: UnavailabilityReason)
        case notConnected(reason: NoConnectionReason)
        case notFoundCharacteristic(String)
        case underlyingError(Error)
    }

    fileprivate var _dataChannelState: DataChannelState = .notStarted
    fileprivate var lock = MutexLock()
    
    fileprivate let deleteProxy: PeripheralDelegateProxy
    fileprivate var serviceInterested = [ServiceInterested]()
    fileprivate var dataChannelsMap = [String: SendDataChannel]()
    fileprivate var characteristicsMap = [String: CBCharacteristic]()
    
    fileprivate var startChannelSuccessHandler: (() -> Void)? = nil
    fileprivate var startChannelFailureHandler: ((DataChannelError) -> Void)? = nil
    
    internal let peripheral: CBPeripheral
    
    public weak var delegate: PeripheralDelegate?
    public weak var receiveDataDelegate: PeripheralReceiveDataDelegate?
    
    public var isConnected: Bool {
        return peripheral.state == .connected
    }
    
    public var identifier: UUID {
        return peripheral.identifier
    }
    
    public var name: String? {
        return peripheral.name
    }
    
    public var dataChannelState: DataChannelState {
        lock.lock()
        let state = _dataChannelState
        lock.unlock()
        return state
    }
    
    public init(peripheral: CBPeripheral) {
        self.deleteProxy = PeripheralDelegateProxy()
        self.peripheral = peripheral
        super.init()
        self.deleteProxy.delegate = self
        self.peripheral.delegate = deleteProxy
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard object != nil, let aPeripheral = object as? Peripheral else {
            return false
        }
        return aPeripheral.peripheral.identifier == peripheral.identifier
    }
    
    /// 先查找您感兴趣的 service & characteristics，然后建立蓝牙从设备与蓝牙主设备间的数据通信服务。
    /// - Parameter serviceInterested: 默认为空，即查找蓝牙从设备所有的 service, characteristics。
    
    /// 先查找您感兴趣的 service & characteristics，然后建立蓝牙从设备与蓝牙主设备间的数据通信服务。
    /// - Parameters:
    ///   - servicesInterested: 默认为空，即查找蓝牙从设备所有的 service, characteristics。
    ///   - successHandler: 数据通信服务启动成功，蓝牙主从设备间可以通信了。
    ///   - failureHandler: 数据通信服务启动失败，无法通信。这时可以断开蓝牙再次尝试，或检测 serivces 参数是否正确。
    public func startDataChannel(_ servicesInterested: [ServiceInterested] = [], successHandler: @escaping () -> Void, failureHandler: @escaping (DataChannelError) -> Void) {
        
        if case DataChannelState.starting = dataChannelState {
            // 正在进行中，直接返回
            print("正在开启数据通道...")
            return
        }
        
        // 开始建立数据通道之前，检查下蓝牙是否可用，蓝牙设备是否已连接
        if case let .unavailable(reason) = InternalAvailability.availability {
            failureHandler(DataChannelError.unavailable(reason: reason))
            return
        }
        
        guard case .connected = peripheral.state else {
            failureHandler(DataChannelError.notConnected(reason: peripheral.noConnectedReason!))
            return
        }
        
        cleanUp()
        transitState(to: .starting)
        
        self.serviceInterested = servicesInterested
        startChannelSuccessHandler = successHandler
        startChannelFailureHandler = failureHandler
        peripheral.discoverServices(ServiceInterested.serviceCBUUIDs(from: servicesInterested))
    }

    /// 通过指定 `characteristic` 发送数据到蓝牙从设备。
    /// - Parameters:
    ///   - data: 可以是任意长度的数据，内部会自动为你发送
    ///   - characteristicUUID: UUID of `characteristic`
    public func sendData(_ data: Data, toCharacteristic characteristicUUID : String) throws {
        
        // 开始建立数据通道之前，检查下蓝牙是否可用，蓝牙设备是否已连接
        if case let .unavailable(reason) = InternalAvailability.availability {
            throw DataChannelError.unavailable(reason: reason)
        }
        
        guard case .connected = peripheral.state else {
            throw DataChannelError.notConnected(reason: peripheral.noConnectedReason!)
        }
        
        guard let dataChannel = dataChannel(by: characteristicUUID) else {
            throw DataChannelError.notFoundCharacteristic(characteristicUUID)
        }
        dataChannel.sendData(data)
    }
    
}

extension CBPeripheral {
    
    var noConnectedReason: Peripheral.NoConnectionReason? {
        switch state {
        case .connecting:
            return .connecting
        case .disconnected:
            return .disconnected
        case .disconnecting:
            return .disconnecting
        default:
            return nil
        }
    }
}

fileprivate extension Peripheral {
    
    func transitState(to newState: DataChannelState) {
        _dataChannelState = newState
    }
    
    func dataChannel(by characteristicUUID: String) -> SendDataChannel? {
        return dataChannelsMap[characteristicUUID]
    }
    
    func cleanUp() {
        dataChannelsMap.values.forEach {
            $0.cancelAllSendDataTasks()
        }
        
        characteristicsMap.values.forEach {
            if isConnected, $0.isNotifying {
                peripheral.setNotifyValue(false, for: $0)
            }
        }
        
        characteristicsMap.removeAll()
        dataChannelsMap.removeAll()
    }
}

extension Peripheral: InternalPeripheralDelegate {
    
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
            let characteristicUUIDs = ServiceInterested.characteristicCBUUIDs(from: serviceInterested, forService: service)
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
            
            if properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
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
        receiveDataDelegate?.peripheralDidRecevieCharacteristicData(self, data: data, characteristicUUID: characteristic.uuid.uuidString)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didFailToUpdateValueForCharacteristic characteristic: CBCharacteristic, error: Error) {
        
    }
    
}
