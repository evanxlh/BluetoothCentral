//
//  ConnectionPool.swift
//
//  Created by Evan Xie on 2/26/20.
//

import Foundation
import CoreBluetooth

internal protocol ConnectionPoolDelegate: class {
    func connectionPool(_ connectionPool: ConnectionPool, peripheralDidDisconnect peripheral: CBPeripheral)
}

/// 负责蓝牙连接集中管理，
/// 设计来自 [BluetoothKit](https://github.com/rhummelmose/BluetoothKit/blob/master/Source/BKConnectionPool.swift)。
internal final class ConnectionPool {
    
    fileprivate var manager: CBCentralManager
    fileprivate let lock = MutexLock()
    fileprivate var _connectionAttempts = [ConnectionAttempt]()
    fileprivate var _connectedPeripherals = [CBPeripheral]()
    
    fileprivate var connectionAttempts: [ConnectionAttempt] {
        lock.lock()
        let attempts = _connectionAttempts
        lock.unlock()
        return attempts;
    }
    
    var connectedPeripherals: [CBPeripheral] {
        lock.lock()
        let connected = _connectedPeripherals
        lock.unlock()
        return connected
    }
    
    weak var delegate: ConnectionPoolDelegate?

    init(manager: CBCentralManager) {
        self.manager = manager
    }

    func connectWithTimeout(_ timeout: TimeInterval, peripheral: CBPeripheral, onSuccess: @escaping () -> Void, onFailure: @escaping (CentralManager.ConnectionError) -> Void) {
        
        guard !connectedPeripherals.contains(peripheral) else {
            runTaskOnMainThread { onFailure(CentralManager.ConnectionError.alreadyConnected) }
            return
        }
        guard !connectionAttempts.map ({ $0.peripheral }).contains(peripheral) else {
            runTaskOnMainThread { onFailure(CentralManager.ConnectionError.connecting) }
            return
        }
        
        let centralState = manager.unifiedState
        guard centralState == .poweredOn else {
            runTaskOnMainThread {
                onFailure(CentralManager.ConnectionError.bluetoothUnavailable(UnavailabilityReason(state: centralState)))
            }
            return
        }
        
        let timer = DispatchTimer()
        timer.schedule(withTimeInterval: timeout, repeats: false) { [weak self] (_) in
            guard let `self` = self else { return }
            self.failConnectionAttempt(self.connectionAttemptForTimer(timer)!, error: .timeout)
        }
        
        let connectionAttempt = ConnectionAttempt(peripheral: peripheral, timer: timer, successHandler: onSuccess, failureHandler: onFailure)
        _connectionAttempts.append(connectionAttempt)
        manager.connect(peripheral, options: nil)
    }
    
    func disconnectPeripheral(_ peripheral: CBPeripheral) -> Bool {
        guard let connectedPeripheral = connectedPeripherals.filter({ $0 == peripheral }).first else {
            return false
        }
        manager.cancelPeripheralConnection(connectedPeripheral)
        return true
    }

    func reset() {
        cancelConnectionAttemps()
        resetConnectedPeripherals()
    }
}

// MARK: - Private Functions

fileprivate extension ConnectionPool {
    
    func connectionAttemptForPeripheral(_ peripheral: CBPeripheral) -> ConnectionAttempt? {
        lock.lock()
        let attempt = _connectionAttempts.filter({ $0.peripheral == peripheral }).first
        lock.unlock()
        return attempt
    }

    func connectionAttemptForTimer(_ timer: DispatchTimer) -> ConnectionAttempt? {
        lock.lock()
        let attempt = connectionAttempts.filter({ $0.timer === timer }).first
        lock.unlock()
        return attempt
    }

    func failConnectionAttempt(_ connectionAttempt: ConnectionAttempt, error: CentralManager.ConnectionError) {
        
        connectionAttempt.timer.invalidate()
        
        lock.lock()
        if let index = _connectionAttempts.firstIndex(of: connectionAttempt) {
            _connectionAttempts.remove(at: index)
        }
        lock.unlock()
        manager.cancelPeripheralConnection(connectionAttempt.peripheral)
        connectionAttempt.failureHandler(error)
    }

    func succeedConnectionAttempt(_ connectionAttempt: ConnectionAttempt) {
        connectionAttempt.timer.invalidate()
        
        lock.lock()
        if let index = _connectionAttempts.firstIndex(of: connectionAttempt) {
            _connectionAttempts.remove(at: index)
        }
        _connectedPeripherals.append(connectionAttempt.peripheral)
        lock.unlock()
        
        connectionAttempt.successHandler()
    }
    
    func cancelConnectionAttemps() {
        let attempts = connectionAttempts
        for attempt in attempts {
            failConnectionAttempt(attempt, error: CentralManager.ConnectionError.cancelled)
        }
        _connectionAttempts.removeAll()
    }
    
    func resetConnectedPeripherals() {
        let connects = connectedPeripherals
        for peripheral in connects {
            delegate?.connectionPool(self, peripheralDidDisconnect: peripheral)
        }
        _connectedPeripherals.removeAll()
    }
    
}

// MARK: CentralManagerConnectionDelegate Implementation

extension ConnectionPool: CentralManagerConnectionDelegate {
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let attempt = connectionAttemptForPeripheral(peripheral) else { return }
        succeedConnectionAttempt(attempt)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Swift.Error?) {
        guard let attempt = connectionAttemptForPeripheral(peripheral) else {  return }
        if error != nil {
            failConnectionAttempt(attempt, error: .failedWithUnderlyingError(error!))
        } else {
            failConnectionAttempt(attempt, error: .failedWithUnderlyingError(InternalError.unknown))
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Swift.Error?) {
        if let index = connectedPeripherals.firstIndex(of: peripheral) {
            _connectedPeripherals.remove(at: index)
            delegate?.connectionPool(self, peripheralDidDisconnect: peripheral)
        }
    }
}
