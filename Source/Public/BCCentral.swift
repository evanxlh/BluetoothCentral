//
//  BCCentral.swift
//
//  Created by Evan Xie on 2/24/20.
//

import Foundation
import CoreBluetooth

public protocol BCCentralDelegate: NSObjectProtocol {
    func central(_ centralManager: BCCentral, availabilityDidUpdate availability: BCAvailability)
    func central(_ centralManager: BCCentral, peripheralDidDisconnect peripheral: CBPeripheral)
}

// MARK: - Object Lifecycle

public final class BCCentral: NSObject {
    
    fileprivate var manager: CBCentralManager
    fileprivate var scanner: Scanner
    fileprivate var connectionPool: ConnectionPool
    
    fileprivate var delegateProxy: CentralDelegateProxy
    
    /// 系统蓝牙的可用状态
    public var availability: BCAvailability {
        return BCAvailability(state: manager.unifiedState)
    }
    
    /// BCCentral 一些重要委托回调
    public weak var delegate: BCCentralDelegate? = nil
    
    public override init() {
        delegateProxy = CentralDelegateProxy()
        manager = CBCentralManager(delegate: nil, queue: nil, options: nil)
        scanner = Scanner(manager: manager)
        connectionPool = ConnectionPool(manager: manager)
        super.init()
        
        delegateProxy.stateDelegate = self
        delegateProxy.discoveryDelegate = scanner
        delegateProxy.connectionDelegate = connectionPool
        manager.delegate = delegateProxy
        connectionPool.delegate = self
    }
}

// MARK: - 蓝牙设备获取

public extension BCCentral {
    
    /// 所有已连接上的蓝牙设备
    var connectedPeripherals: [CBPeripheral] {
        return connectionPool.connectedPeripherals
    }
    
    func retrievePeripheral(withIdentifier identifier: UUID) -> CBPeripheral? {
        return retrievePeripherals(withIdentifiers: [identifier]).first
    }
    
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        return manager.retrievePeripherals(withIdentifiers: identifiers)
    }
    
    func retrieveConnectedPeripherals(withServiceUUIDs uuids: [CBUUID]) -> [CBPeripheral] {
        return manager.retrieveConnectedPeripherals(withServices: uuids)
    }
}

// MARK: - 蓝牙设备扫描

public extension BCCentral {
    
    /// 扫描蓝牙可能遇到的错误
    /// - bluetoothUnavailable 蓝牙不可用，原因见 `UnavailabilityReason`
    /// - scanning 正在扫描中
    enum ScanError: Swift.Error {
        case bluetoothUnavailable(UnavailabilityReason)
        case scanning
    }
    
    /// 扫描模式，一直扫描或固定时间扫描
    enum ScanMode {
        case infinitely
        case fixedDuration(TimeInterval)
    }
    
    /// 扫描蓝牙设备过滤器
    struct ScanFilter {
        
        public typealias CustomFilterHandler = (BCDiscovery) -> Bool
        
        /// 只扫描包含指定 service uuids 的蓝牙设备，默认为空(全部扫描).
        public var serviceUUIDs: [CBUUID]
        
        /// 是否更新重复的蓝牙设备，默认为 `false` (不更新).
        ///
        /// 开启后，同一个蓝牙设备可能会广播多次；关闭后，Core Bluetooth 会将多个广播信息合成一个再发出来，
        /// [详细请看这里](https://stackoverflow.com/questions/11557500/corebluetooth-central-manager-callback-diddiscoverperipheral-twice)。
        public var isUpdateDuplicatesEnabled: Bool
        
        /// 如果以上过滤条件不能满足，你可以实现自己的过滤逻辑。
        public var customFilter: CustomFilterHandler?
        
        public init(serviceUUIDs: [CBUUID] = [], isUpdateDuplicatesEnabled: Bool = false, customFilter: CustomFilterHandler? = nil) {
            self.serviceUUIDs = serviceUUIDs
            self.isUpdateDuplicatesEnabled = isUpdateDuplicatesEnabled
            self.customFilter = customFilter
        }
    }
    
    /// 开始扫描蓝牙设备
    /// - Parameters:
    ///   - mode: 扫描模式，见 `ScanMode`
    ///   - filter: 扫描过滤条件，默认为扫描所有蓝牙设备。
    ///   - onProgress: 扫描进度，当发现新设备时，就会调用，所以这个回调可能会被多次触发。
    ///   - onCompletion: 扫描完成，返回本次扫描过程中所有发现的蓝牙设备。扫描时间到了，或主动调用 `stopScan`，都会触发这个回调。
    ///   - onError: 扫描出现错误时触发，返回 `ScanError`。
    func startScan(withMode mode: ScanMode, filter: ScanFilter = ScanFilter(), onProgress: (([BCDiscovery]) -> Void)? = nil, onCompletion: @escaping ([BCDiscovery]) -> Void, onError: ((ScanError) -> Void)? = nil) {
        do {
            try scanner.startScan(withMode: mode, filter: filter, onProgress: onProgress, onCompletion: onCompletion)
        } catch {
            onError?(error as! ScanError)
        }
    }
    
    /// 停止扫描，如果没有在扫描，调用它也没关系。
    func stopScan() {
        scanner.stop()
    }
}

// MARK: - 蓝牙设备连接

public extension BCCentral {
    
    /// 扫描蓝牙可能遇到的错误
    /// - bluetoothUnavailable 蓝牙不可用，原因见 `UnavailabilityReason`
    /// - connecting 正在连接中(正在连接蓝牙设备过程中，又再次连接此蓝牙设备会触发此错误)
    /// - alreadyConnected 已经连接上了(蓝牙设备已连上，又发起连接此蓝牙设备时会触发此错误)
    /// - timeout 连接蓝牙设备超时
    /// - cancelled 蓝牙设备蓝牙被取消(比如正在连接过程中，系统蓝牙被关了)
    /// - underlyingError 蓝牙连接底层错误
    enum ConnectionError: Swift.Error {
        case bluetoothUnavailable(UnavailabilityReason)
        case connecting
        case alreadyConnected
        case timeout
        case cancelled
        case failedWithUnderlyingError(Swift.Error)
    }
    
    /// 连接蓝牙设备
    /// - Parameters:
    ///   - timeout: 给定时间过去了，连接超时
    ///   - peripheral: 需要连接的蓝牙设备
    ///   - onSuccess: 连接成功后触发
    ///   - onFailure: 连接过程中遇到错误时触发，详细错误见 `ConnectionError`
    func connect(withTimeout timeout: TimeInterval = 5, peripheral: CBPeripheral, onSuccess: @escaping () -> Void, onFailure: @escaping (ConnectionError) -> Void) {
        connectionPool.connectWithTimeout(timeout, peripheral: peripheral, onSuccess: onSuccess, onFailure: onFailure)
    }
    
    /// 断开蓝牙设备连接。如果返回 `false`，说明本来就没有与给定蓝牙设备连接。
    @discardableResult
    func disconnectPeripheral(_ peripheral: CBPeripheral) -> Bool {
        return connectionPool.disconnectPeripheral(peripheral)
    }
}

// MARK: - Handle BCCentral State

extension BCCentral: CentralStateDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        let unifiedState = central.unifiedState
        switch central.unifiedState {
        case .poweredOn:
            runTaskOnMainThread {
                self.delegate?.central(self, availabilityDidUpdate: .available)
            }
            
        default:
            let reason = UnavailabilityReason(state: unifiedState)
            stopOngoingTasks()
            runTaskOnMainThread {
                self.delegate?.central(self, availabilityDidUpdate: .unavailable(reason: reason))
            }
        }
    }
    
    private func stopOngoingTasks() {
        scanner.stop()
        connectionPool.reset()
    }
}

extension BCCentral: ConnectionPoolDelegate {
    
    func connectionPool(_ connectionPool: ConnectionPool, peripheralDidDisconnect peripheral: CBPeripheral) {
        runTaskOnMainThread {
            self.delegate?.central(self, peripheralDidDisconnect: peripheral)
        }
    }
}


