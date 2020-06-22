//
//  CentralManager.swift
//
//  Created by Evan Xie on 2/24/20.
//

import Foundation
import CoreBluetooth

/// 想要监听系统蓝牙是否可用事件的观察者需实现这个协议
public protocol BluetoothAvailabilityObserver: AnyObject {
    func centralManager(_ centralManager: CentralManager, availabilityDidUpdate availability: Availability)
}

/// 想要监听蓝牙设备断开事件的观察者需实现这个协议
public protocol PeripheralDisconnectedObserver: AnyObject {
    func centralManager(_ centralManager: CentralManager, peripheralDidDisconnect peripheral: Peripheral)
}

// MARK: - Object Lifecycle

public final class CentralManager: NSObject {
    
    fileprivate let queue: DispatchQueue
    fileprivate var manager: CBCentralManager
    fileprivate var scanner: Scanner
    fileprivate var connectionPool: ConnectionPool
    fileprivate var delegateProxy: CentralDelegateProxy
    
    fileprivate var availabilityObservers = [AnyObject]()
    fileprivate var disconnectedObservers = [AnyObject]()
    
    /// 系统蓝牙的可用状态
    public var availability: Availability {
        return Availability(state: manager.unifiedState)
    }
    
    public override init() {
        queue = DispatchQueue(label: "queue.framework.BluetoothCentral")
        delegateProxy = CentralDelegateProxy()
        manager = CBCentralManager(delegate: nil, queue: queue, options: nil)
        scanner = Scanner(manager: manager)
        connectionPool = ConnectionPool(manager: manager)
        super.init()
        
        connectionPool.delegate = self
        delegateProxy.stateDelegate = self
        delegateProxy.discoveryDelegate = scanner
        delegateProxy.connectionDelegate = connectionPool
        manager.delegate = delegateProxy
    }
    
    deinit {
        removeAllBluetoothAvailabilityObservers()
        removeAllPeripheralDisconnectedObservers()
    }
    
    /// MARK: - 监听系统蓝牙是否可用
    
    /// 让 Observer 监听系统蓝牙是否可用事件。
    ///
    /// - 这里是对 `observer` 进行弱引用。
    public func addBluetoothAvailabilityObserver<Observer>(_ observer: Observer) where Observer: BluetoothAvailabilityObserver {
        let weakObserver = WeakObject(object: observer)
        if !availabilityObservers.contains(where: { $0 as! WeakObject<Observer> == weakObserver }) {
            availabilityObservers.append(weakObserver)
        }
    }
    
    public func removeBluetoothAvailabilityObserver<Observer>(_ observer: Observer) where Observer: BluetoothAvailabilityObserver {
        let weakObserver = WeakObject(object: observer)
        if let index = availabilityObservers.firstIndex(where: { $0 as! WeakObject<Observer> == weakObserver}) {
            availabilityObservers.remove(at: index)
        }
    }
    
    public func removeAllBluetoothAvailabilityObservers() {
        availabilityObservers.removeAll()
    }
    
    /// MARK: - 监听蓝牙设备断开
    
    /// 让 Observer 监听蓝牙断开事件。
    ///
    /// - 这里是对 `observer` 进行弱引用。
    public func addPeripheralDisconnectedObserver<Observer>(_ observer: Observer) where Observer: PeripheralDisconnectedObserver {
        let weakObserver = WeakObject(object: observer)
        if !disconnectedObservers.contains(where: { $0 as! WeakObject<Observer> == weakObserver }) {
            disconnectedObservers.append(weakObserver)
        }
    }
    
    public func removePeripheralDisconnectedObserver<Observer>(_ observer: Observer) where Observer: PeripheralDisconnectedObserver {
        let weakObserver = WeakObject(object: observer)
        if let index = disconnectedObservers.firstIndex(where: { $0 as! WeakObject<Observer> == weakObserver}) {
            disconnectedObservers.remove(at: index)
        }
    }
    
    public func removeAllPeripheralDisconnectedObservers() {
        disconnectedObservers.removeAll()
    }
}

// MARK: - 蓝牙设备获取

public extension CentralManager {
    
    /// App 已连接上的所有蓝牙设备
    var connectedPeripherals: [Peripheral] {
        return connectionPool.connectedPeripherals
    }
    
    func retrievePeripheral(withIdentifier identifier: UUID) -> CBPeripheral? {
        return retrievePeripherals(withIdentifiers: [identifier]).first
    }
    
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        return manager.retrievePeripherals(withIdentifiers: identifiers)
    }
    
    /// 获取系统已连上的所有蓝牙设备，包括 其它 app 已连接上的蓝牙设备
    func retrieveConnectedPeripherals(withServiceUUIDs uuidStrings: [String]) -> [Peripheral] {
        let uuids = uuidStrings.map { CBUUID(string: $0) }
        return manager.retrieveConnectedPeripherals(withServices: uuids).map { Peripheral(peripheral: $0) }
    }
}

// MARK: - 蓝牙设备扫描

public extension CentralManager {
    
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
        
        public typealias CustomFilterHandler = (PeripheralDiscovery) -> Bool
        
        /// 只扫描包含指定 service uuids 的蓝牙设备，默认为空(全部扫描).
        public let serviceUUIDs: [CBUUID]
        
        /// 是否更新重复的蓝牙设备，默认为 `false` (不更新).
        ///
        /// 开启后，同一个蓝牙设备可能会广播多次；关闭后，Core Bluetooth 会将多个广播信息合成一个再发出来，
        /// [详细请看这里](https://stackoverflow.com/questions/11557500/corebluetooth-central-manager-callback-diddiscoverperipheral-twice)。
        public var isUpdateDuplicatesEnabled: Bool
        
        /// 如果以上过滤条件不能满足，你可以实现自己的过滤逻辑。
        public var customFilter: CustomFilterHandler?
        
        public init(serviceUUIDs: [String] = [], isUpdateDuplicatesEnabled: Bool = false, customFilter: CustomFilterHandler? = nil) {
            self.serviceUUIDs = serviceUUIDs.map { CBUUID(string: $0) }
            self.isUpdateDuplicatesEnabled = isUpdateDuplicatesEnabled
            self.customFilter = customFilter
        }
    }
    
    /// 扫描到的蓝牙设备变化
    ///
    /// - updated(PeripheralDiscovery, Int): 已更新的 `PeripheralDiscovery` 及它的索引，可用于 table view reload row.
    /// - new(PeripheralDiscovery): 发现新的蓝牙设备.
    enum PeripheralDiscoveryChange {
        case updated(PeripheralDiscovery, Int)
        case new(PeripheralDiscovery)
    }
    
    /// 开始扫描蓝牙设备
    /// - Parameters:
    ///   - mode: 扫描模式，见 `ScanMode`
    ///   - filter: 扫描过滤条件，默认为扫描所有蓝牙设备。
    ///   - onProgress: 扫描进度，当发现新的蓝牙设备或已发现的蓝牙设备发生变化时，就会被调用。
    ///   - onCompletion: 扫描完成，返回本次扫描过程中所有发现的蓝牙设备。扫描时间到了，或主动调用 `stopScan`，都会触发这个回调。
    ///   - onError: 扫描出现错误时触发，返回 `ScanError`。
    func startScan(withMode mode: ScanMode, filter: ScanFilter? = nil, onProgress: ((_ change: PeripheralDiscoveryChange) -> Void)? = nil, onCompletion: @escaping ([PeripheralDiscovery]) -> Void, onError: ((ScanError) -> Void)? = nil) {
        do {
            let filter = filter ?? ScanFilter()
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

public extension CentralManager {
    
    typealias ConnectionSuccessBlock = (Peripheral) -> Void
    typealias ConnectionFailureBlock = (Peripheral, ConnectionError) -> Void
    
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
    func connect(withTimeout timeout: TimeInterval = 5, peripheral: Peripheral, onSuccess: @escaping ConnectionSuccessBlock, onFailure: @escaping ConnectionFailureBlock) {
        peripheral.manager = self
        connectionPool.connectWithTimeout(timeout, peripheral: peripheral, onSuccess: onSuccess, onFailure: onFailure)
    }
    
    /// 断开蓝牙设备连接。如果返回 `false`，说明本来就没有与给定蓝牙设备连接。
    @discardableResult
    func disconnectPeripheral(_ peripheral: Peripheral) -> Bool {
        return connectionPool.disconnectPeripheral(peripheral)
    }
}

// MARK: - Handle CentralManager State

extension CentralManager: CentralStateDelegate {
    
    func triggerAvailabilityUpdate(_ availability: Availability) {
        runTaskOnMainThread { [weak self] in
            guard let `self` = self else { return }
            self.availabilityObservers.forEach {
                guard let weakObject = $0 as? WeakObject<AnyObject> else { return }
                guard let observer = weakObject.object as? BluetoothAvailabilityObserver else { return }
                observer.centralManager(self, availabilityDidUpdate: availability)
            }
        }
    }
    
    func triggerDisconnect(for peripheral: Peripheral) {
        try? peripheral.invalidateAllServices()
        runTaskOnMainThread { [weak self] in
            guard let `self` = self else { return }
            self.disconnectedObservers.forEach {
                guard let weakObject = $0 as? WeakObject<AnyObject> else { return }
                guard let observer = weakObject.object as? PeripheralDisconnectedObserver else { return }
                observer.centralManager(self, peripheralDidDisconnect: peripheral)
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        let unifiedState = central.unifiedState
        switch central.unifiedState {
        case .poweredOn:
            triggerAvailabilityUpdate(.available)
            
        default:
            let reason = UnavailabilityReason(state: unifiedState)
            stopOngoingTasks()
            triggerAvailabilityUpdate(.unavailable(reason: reason))
        }
    }
    
    private func stopOngoingTasks() {
        scanner.stop()
        connectionPool.reset()
    }
}

extension CentralManager: ConnectionPoolDelegate {
    
    func connectionPool(_ connectionPool: ConnectionPool, peripheralDidDisconnect peripheral: Peripheral) {
        triggerDisconnect(for: peripheral)
    }
}


