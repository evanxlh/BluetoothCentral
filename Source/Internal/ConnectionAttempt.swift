//
//  ConnectionAttempt.swift

//  Created by Evan Xie on 2/26/20.
//

import Foundation
import CoreBluetooth

/// 保存蓝牙尝试连接的信息，连接成功后会被移除。
internal final class ConnectionAttempt: Equatable {

    let timer: DispatchTimer
    let peripheral: CBPeripheral
    let successHandler: () -> Void
    let failureHandler: (CentralManager.ConnectionError) -> Void

    init(peripheral: CBPeripheral, timer: DispatchTimer, successHandler: @escaping () -> Void, failureHandler: @escaping (CentralManager.ConnectionError) -> Void) {
        self.peripheral = peripheral
        self.timer = timer
        self.successHandler = successHandler
        self.failureHandler = failureHandler
    }
    
    static func == (lhs: ConnectionAttempt, rhs: ConnectionAttempt) -> Bool {
        return (lhs.peripheral.identifier == rhs.peripheral.identifier)
    }
}
