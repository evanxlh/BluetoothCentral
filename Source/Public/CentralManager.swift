//
//  CentralManager.swift
//
//  Created by Evan Xie on 2/24/20.
//

import Foundation
import CoreBluetooth

public protocol CentralManagerDelegate: NSObjectProtocol {
    func centralManager(_ centralManager: CentralManager, availabilityDidUpdate availability: Availability)
    func centralManager(_ centralManager: CentralManager, peripheralDidDisconnect peripheral: CBPeripheral)
}

// MARK: - Object Lifecycle

public final class CentralManager: NSObject {
    
    // MARK: - Internal Stuff
    
    fileprivate var manager: CBCentralManager
    fileprivate var stateMachine: CentralStateMachine
    fileprivate var scanner: Scanner
    fileprivate var connectionPool: ConnectionPool
    
    fileprivate var delegateProxy: CentralManagerDelegateProxy
    
    // MARK: - Public APIs
    
    public var availability: Availability {
        return Availability(state: manager.unifiedState)
    }

    public var connectedPeripherals: [CBPeripheral] {
        return connectionPool.connectedPeripherals
    }
    
    public weak var delegate: CentralManagerDelegate? = nil
    
    public override init() {
        stateMachine = CentralStateMachine()
        delegateProxy = CentralManagerDelegateProxy()
        manager = CBCentralManager(delegate: nil, queue: nil, options: nil)
        scanner = Scanner(manager: manager, filter: ScanFilter())
        connectionPool = ConnectionPool(manager: manager)
        
        super.init()
        
        delegateProxy.stateDelegate = self
        delegateProxy.discoveryDelegate = scanner
        delegateProxy.connectionDelegate = connectionPool
        manager.delegate = delegateProxy
        connectionPool.delegate = self
    }
    
    public func startScan(withMode mode: ScanMode, filter: ScanFilter = ScanFilter(), progressHandler: ScanProgressHandler? = nil, completionHandler: @escaping ScanCompletionHandler) {
        do {
            scanner.filter = filter
            try stateMachine.validateOperationCanBeExecuted(.scan)
            try scanner.start(withMode: mode, progressHandler: progressHandler, completionHandler: { [weak self] (result) in
                switch result {
                case .success(let discoveries):
                    try? self?.stateMachine.validateOperationCanBeExecuted(.setAvailable)
                    completionHandler(.success(discoveries))
                    
                case .failure(let error):
                    completionHandler(.failure(.internalError(error)))
                }
            })
        } catch {
            completionHandler(.failure(.internalError(error)))
        }
    }
    
    public func stopScan() {
        scanner.stop()
    }
    
    public func connect(withTimeout timeout: TimeInterval = 3, peripheral: CBPeripheral, completionHandler: @escaping ConnectCompletionHandler) {
        do {
            try stateMachine.validateOperationCanBeExecuted(.connect)
            try connectionPool.connectWithTimeout(timeout, peripheral: peripheral) { [weak self] (peripheral, result) in
                switch result {
                case .success:
                    try? self?.stateMachine.validateOperationCanBeExecuted(.setAvailable)
                    completionHandler(peripheral, .success(()))
                case .failure(let error):
                    completionHandler(peripheral, .failure(.internalError(error)))
                }
            }
        } catch {
            completionHandler(peripheral, .failure(.internalError(error)))
        }
    }
    
    public func disconnectPeripheral(_ peripheral: CBPeripheral) throws {
        do {
            try connectionPool.disconnectPeripheral(peripheral)
        } catch {
            throw Error.internalError(error)
        }
    }
    
    public func retrievePeripheral(withIdentifier identifier: UUID) -> CBPeripheral? {
        return retrievePeripherals(withIdentifiers: [identifier]).first
    }

    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        return manager.retrievePeripherals(withIdentifiers: identifiers)
    }
    
    public func retrieveConnectedPeripherals(withServiceUUIDs uuids: [CBUUID]) -> [CBPeripheral] {
        return manager.retrieveConnectedPeripherals(withServices: uuids)
    }
}

// MARK: - Handle CentralManager State

extension CentralManager: CentralManagerStateDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        let unifiedState = central.unifiedState
        switch central.unifiedState {
        case .poweredOn:
            try? stateMachine.validateOperationCanBeExecuted(.setAvailable)
            runTaskOnMainThread { [weak self] in
                guard let `self` = self else { return }
                self.delegate?.centralManager(self, availabilityDidUpdate: .available)
            }
            
        default:
            let reason = UnavailabilityReason(state: unifiedState)
            handleUnavailableState(by: reason)
            runTaskOnMainThread { [weak self] in
                guard let `self` = self else { return }
                self.delegate?.centralManager(self, availabilityDidUpdate: .unavailable(reason: reason))
            }
        }
    }
    
    private func stopOngoingTasksWhenUnavailable() {
        scanner.stop()
        connectionPool.reset()
    }
    
    private func handleUnavailableState(by reason: UnavailabilityReason ) {
        try? stateMachine.validateOperationCanBeExecuted(.setUnavailable(reason: reason))
        stopOngoingTasksWhenUnavailable()
    }
}

extension CentralManager: ConnectionPoolDelegate {
    
    func connectionPool(_ connectionPool: ConnectionPool, peripheralDidDisconnect peripheral: CBPeripheral) {
        delegate?.centralManager(self, peripheralDidDisconnect: peripheral)
    }
}


