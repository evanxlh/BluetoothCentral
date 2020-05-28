//
//  CentralManagerDelegateProxy.swift

//  Created by Evan Xie on 2/25/20.
//

import Foundation
import CoreBluetooth

/// 根据职责将 `CBCentralManagerDelegate` 拆分，分别委托给不同的职责类。
///
/// 设计来自 [BluetoothKit](https://github.com/rhummelmose/BluetoothKit/blob/master/Source/BKCBCentralManagerDelegateProxy.swift)。
internal class CentralManagerDelegateProxy: NSObject, CBCentralManagerDelegate {

    weak var stateDelegate: CentralManagerStateDelegate?
    weak var discoveryDelegate: CentralManagerDiscoveryDelegate?
    weak var connectionDelegate: CentralManagerConnectionDelegate?

    // MARK: - State Delegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateDelegate?.centralManagerDidUpdateState(central)
    }
    
    // MARK: - Discovery Delegate
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveryDelegate?.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }
    
    // MARK: - Connection Delegate

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionDelegate?.centralManager(central, didConnect: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionDelegate?.centralManager(central, didFailToConnect: peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionDelegate?.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }
    
    // MARK: - Other Not Implemented Delegate
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        // Not implemented
    }
    
    func centralManager(_ central: CBCentralManager, didUpdateANCSAuthorizationFor peripheral: CBPeripheral) {
        // Not implemented
    }
}

internal protocol CentralManagerStateDelegate: AnyObject {
    func centralManagerDidUpdateState(_ central: CBCentralManager)
}

internal protocol CentralManagerDiscoveryDelegate: AnyObject {
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber)
}

internal protocol CentralManagerConnectionDelegate: AnyObject {
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?)
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
}
