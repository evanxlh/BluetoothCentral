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

internal extension ConnectionPool {
    
    // MARK: - Datatype Definition
    
    typealias CompletionHandler = (_ peripheral: CBPeripheral, _ result: Result<Void, ConnectionPool.InternalError>) -> Void

    enum InternalError: Swift.Error {
        case alreadyConnected
        case alreadyConnecting
        case cancelled
        case noConnectionAttemptForPeripheral
        case noConnectionForPeripheral
        case timeout
        case underlyingError(Swift.Error?)
    }
}

/// 负责蓝牙连接集中管理，
/// 设计来自 [BluetoothKit](https://github.com/rhummelmose/BluetoothKit/blob/master/Source/BKConnectionPool.swift)。
internal final class ConnectionPool {
    
    fileprivate var manager: CBCentralManager
    
    weak var delegate: ConnectionPoolDelegate?
    var connectedPeripherals = [CBPeripheral]()
    var connectionAttempts = [ConnectionAttempt]()

    init(manager: CBCentralManager) {
        self.manager = manager
    }

    func connectWithTimeout(_ timeout: TimeInterval, peripheral: CBPeripheral, completionHandler: @escaping CompletionHandler) throws {
        
        guard !connectedPeripherals.contains(peripheral) else {
            throw InternalError.alreadyConnected
        }
        guard !connectionAttempts.map ({ $0.peripheral }).contains(peripheral) else {
            throw InternalError.alreadyConnecting
        }
        
        let timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(fireConnectionTimeout), userInfo: nil, repeats: false)
        let connectionAttempt = ConnectionAttempt(peripheral: peripheral, timer: timer, completionHandler: completionHandler)
        connectionAttempts.append(connectionAttempt)
        manager.connect(peripheral, options: nil)
    }

    func cancelConnectionAttemptForPeripheral(_ peripheral: CBPeripheral) throws {
        let connectionAttempt = connectionAttemptForPeripheral(peripheral)
        guard let attempt = connectionAttempt else {
            throw InternalError.noConnectionAttemptForPeripheral
        }
        failConnectionAttempt(attempt, error: .cancelled)
    }

    func disconnectPeripheral(_ peripheral: CBPeripheral) throws {
        guard let connectedPeripheral = connectedPeripherals.filter({ $0 == peripheral }).first else {
            throw InternalError.noConnectionForPeripheral
        }
        manager.cancelPeripheralConnection(connectedPeripheral)
    }

    func reset() {
        cancelConnectionAttemps()
        resetConnectedPeripherals()
    }
}

// MARK: - Private Functions

fileprivate extension ConnectionPool {
    
    func connectionAttemptForPeripheral(_ peripheral: CBPeripheral) -> ConnectionAttempt? {
        return connectionAttempts.filter({ $0.peripheral == peripheral }).first
    }

    func connectionAttemptForTimer(_ timer: Timer) -> ConnectionAttempt? {
        return connectionAttempts.filter({ $0.timer == timer }).first
    }

    @objc func fireConnectionTimeout(_ timer: Timer) {
        failConnectionAttempt(connectionAttemptForTimer(timer)!, error: .timeout)
    }

    func failConnectionAttempt(_ connectionAttempt: ConnectionAttempt, error: InternalError) {
        connectionAttempt.timer.invalidate()
        if let index = connectionAttempts.firstIndex(of: connectionAttempt) {
            connectionAttempts.remove(at: index)
        }
        manager.cancelPeripheralConnection(connectionAttempt.peripheral)
        connectionAttempt.completionHandler(connectionAttempt.peripheral, .failure(error))
    }

    func succeedConnectionAttempt(_ connectionAttempt: ConnectionAttempt) {
        connectionAttempt.timer.invalidate()
        if let index = connectionAttempts.firstIndex(of: connectionAttempt) {
            connectionAttempts.remove(at: index)
        }
        connectedPeripherals.append(connectionAttempt.peripheral)
        connectionAttempt.completionHandler(connectionAttempt.peripheral, .success(()))
    }
    
    func cancelConnectionAttemps() {
        for connectionAttempt in connectionAttempts {
            failConnectionAttempt(connectionAttempt, error: .cancelled)
        }
        connectionAttempts.removeAll()
    }
    
    func resetConnectedPeripherals() {
        for peripheral in connectedPeripherals {
            delegate?.connectionPool(self, peripheralDidDisconnect: peripheral)
        }
        connectedPeripherals.removeAll()
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
        failConnectionAttempt(attempt, error: .underlyingError(error))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Swift.Error?) {
        if let index = connectedPeripherals.firstIndex(of: peripheral) {
            connectedPeripherals.remove(at: index)
            delegate?.connectionPool(self, peripheralDidDisconnect: peripheral)
        }
    }
    
}
