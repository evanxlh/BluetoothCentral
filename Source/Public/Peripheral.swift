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

/// 蓝牙设备(用于从设备)，主要负责主从设备间的数据通信。
public class Peripheral: NSObject {
    
    fileprivate var lock = MutexLock()
    fileprivate var _state: State = .notReady
    fileprivate let deleteProxy: PeripheralDelegateProxy
    fileprivate var serviceInterested = [ServiceInterested]()
    
    /// [UUIDString: Any]
    fileprivate var dataChannelsMap = [String: SendDataChannel]()
    fileprivate var characteristicsMap = [String: CBCharacteristic]()
    fileprivate var cacheForServiceInfos = [String: ServiceInfo]()
    
    fileprivate var startChannelSuccessHandler: (([String: ServiceInfo]) -> Void)? = nil
    fileprivate var startChannelFailureHandler: ((Error) -> Void)? = nil
    
    internal let peripheral: CBPeripheral
    
    public weak var delegate: PeripheralDelegate?
    public weak var receiveDataDelegate: PeripheralReceiveDataDelegate?
    
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
}

// MARK: - 蓝牙设备的一些信息

extension Peripheral {
    
    public enum State: Int {
        case notReady
        case preparing
        case ready
    }
    
    public enum ConnectionState: Int {
        case connecting
        case connected
        case disconnecting
        case disconnected
    }
    
    public var connectionState: ConnectionState {
        switch peripheral.state {
        case .connecting:
            return .connecting
        case .connected:
            return .connected
        case .disconnecting:
            return .disconnecting
        case .disconnected:
            return .disconnected
        @unknown default:
            return .disconnected
        }
    }
    
    public var isConnected: Bool {
        return peripheral.state == .connected
    }
    
    public var identifier: UUID {
        return peripheral.identifier
    }
    
    public var name: String? {
        return peripheral.name
    }
    
    public var state: State {
        lock.lock()
        let state = _state
        lock.unlock()
        return state
    }
}

// MARK: - 服务准备 & 销毁

extension Peripheral {
    
    public enum NotConnectedReason: Int {
        case connecting
        case disconnecting
        case disconnected
        
        init?(_ connectionState: ConnectionState) {
            switch connectionState {
            case .connecting:
                self = NotConnectedReason.connecting
            case .disconnecting:
                self = NotConnectedReason.disconnecting
            case .disconnected:
                self = NotConnectedReason.disconnected
            default:
                return nil
            }
        }
    }
    
    public indirect enum Error: Swift.Error {
        case bluethoothUnavailable(reason: UnavailabilityReason)
        case peripheralNotConnected(reason: NotConnectedReason)
        case preparingPeripheralServices
        case notFoundCharacteristic(uuid: String)
        case underlyingError(Error)
    }
    
    /// 对已发现的 services 的缓存(UUID 与 ServiceInfo 健值对)。如果 `data channel` 还未建立，则为空。
    /// 当 `openDataChannel` 调用成功后，所有发现的 services 都会缓存在这里。
    public var serviceInfos: [String: ServiceInfo] {
        return cacheForServiceInfos
    }
    
    /// 先查找您感兴趣的 service & characteristics，然后建立蓝牙从设备与蓝牙主设备间的数据通信服务。
    /// - Parameter serviceInterested: 默认为空，即查找蓝牙从设备所有的 service, characteristics。
    
    /// 先查找您感兴趣的 service & characteristics，然后建立蓝牙从设备与蓝牙主设备间的数据通信服务。
    /// - Parameters:
    ///   - servicesInterested: 默认为空，即查找蓝牙从设备所有的 service, characteristics, 并准备好必要的通信通道。
    ///   - successHandler: 数据通信服务启动成功，蓝牙主从设备间可以通信了。返回实际上发现的 services 信息: [ServiceUUIDString: ServiceInfo]。
    ///   - failureHandler: 数据通信服务启动失败，无法通信。这时可以断开蓝牙再次尝试，或检测 serivces 参数是否正确。
    public func prepareServicesToReady(_ servicesInterested: [ServiceInterested] = [], successHandler: @escaping ([String: ServiceInfo]) -> Void, failureHandler: @escaping (Error) -> Void) {
        do {
            try validateBluetoothConnection()
        } catch {
            failureHandler(error as! Error)
        }
        
        cleanUp()
        transitState(to: .preparing)
        
        self.serviceInterested = servicesInterested
        startChannelSuccessHandler = successHandler
        startChannelFailureHandler = failureHandler
        peripheral.discoverServices(ServiceInterested.serviceCBUUIDs(from: servicesInterested))
    }
    
    /// 当蓝牙设备断开或想主动关闭通信通道，都需要调用这个方法.
    ///
    /// - Throws: Error.preparingPeripheralServices
    public func invalidateAllServices() throws {
        if case State.preparing = state {
            throw Error.preparingPeripheralServices
        }
        cleanUp()
        transitState(to: .notReady)
    }
}

// MARK: - 数据读写

extension Peripheral {
    
    /// 读取指定的 ``characteristic` 的数据。
    public func readData(from characteristicUUID: String, successHandler: (Data) -> Void, failureHandler: (Error) -> Void) {
        do {
            try validateBluetoothConnection()
            guard let characteristic = characteristicsMap[characteristicUUID] else {
                throw Error.notFoundCharacteristic(uuid: characteristicUUID)
            }
            peripheral.readValue(for: characteristic)
        } catch {
            failureHandler(error as! Error)
        }
    }
    
    /// 通过指定 `characteristic` 发送数据到蓝牙从设备。
    /// - Parameters:
    ///   - data: 可以是任意长度的数据，内部会自动为你发送
    ///   - characteristicUUID: UUID of `characteristic`
    /// - Throws: 见 `DataChannelError`
    public func writeData(_ data: Data, toCharacteristic characteristicUUID : String) throws {
        try validateBluetoothConnection()
        guard let dataChannel = dataChannel(by: characteristicUUID) else {
            throw Error.notFoundCharacteristic(uuid: characteristicUUID)
        }
        dataChannel.sendData(data)
    }
}

// MARK: - Private Functions

fileprivate extension Peripheral {
    
    func validateBluetoothConnection() throws {
        
        // 开始建立数据通道之前，检查下蓝牙是否可用，蓝牙设备是否已连接
        if case let .unavailable(reason) = InternalAvailability.availability {
            throw Error.bluethoothUnavailable(reason: reason)
        }
        
        // 检查蓝牙外设是否已连接
        guard case .connected = peripheral.state else {
            throw Error.peripheralNotConnected(reason: NotConnectedReason(connectionState)!)
        }
        
        if case State.preparing = state {
            throw Error.preparingPeripheralServices
        }
    }
    
    func transitState(to newState: State) {
        _state = newState
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
        cacheForServiceInfos.removeAll()
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
            let serviceInfo = ServiceInfo(uuid: service.uuid.uuidString, isPrimary: service.isPrimary)
            let characteristicUUIDs = ServiceInterested.characteristicCBUUIDs(from: serviceInterested, forService: service)
            cacheForServiceInfos[service.uuid.uuidString] = serviceInfo
            peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didFailToDiscoverServices error: Swift.Error) {
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService) {
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            
            let uuidString = characteristic.uuid.uuidString
            let properties = characteristic.properties
            self.characteristicsMap[uuidString] = characteristic
            
            if var serviceInfo = cacheForServiceInfos[service.uuid.uuidString] {
                // 缓存 characteristic info 到 cacheForServiceInfos
                let characteristicInfo = CharacteristicInfo(uuid: uuidString, properties: properties)
                serviceInfo._characteristicInfos[uuidString] = characteristicInfo
                cacheForServiceInfos[serviceInfo.uuid] = serviceInfo
            }
            
            if properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            if properties.contains(.write) || properties.contains(.writeWithoutResponse) {
                // 为可写数据的 characteristic 创建数据发送通道
                let dataChannel = SendDataChannel(peripheral: peripheral, characteristic: characteristic)
                dataChannelsMap[characteristic.uuid.uuidString] = dataChannel
            }
        }
        
        runTaskOnMainThread { [weak self] in
            guard let `self` = self else { return }
            self.startChannelSuccessHandler?(self.cacheForServiceInfos)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didFailToDiscoverCharacteristicsForService service: CBService, error: Swift.Error) {
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic) {
        guard let data = characteristic.value, data.count > 0 else { return }
        receiveDataDelegate?.peripheralDidRecevieCharacteristicData(self, data: data, characteristicUUID: characteristic.uuid.uuidString)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didFailToUpdateValueForCharacteristic characteristic: CBCharacteristic, error: Swift.Error) {
        
    }
    
}
