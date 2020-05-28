//
//  ConnectionAttempt.swift

//  Created by Evan Xie on 2/26/20.
//

import Foundation
import CoreBluetooth

/// 保存蓝牙尝试连接的信息，连接成功后会被移除。
internal final class ConnectionAttempt: Equatable {

    let timer: Timer
    let peripheral: CBPeripheral
    let completionHandler: ConnectionPool.CompletionHandler

    init(peripheral: CBPeripheral, timer: Timer, completionHandler: @escaping ConnectionPool.CompletionHandler) {
        self.peripheral = peripheral
        self.timer = timer
        self.completionHandler = completionHandler
    }
    
    static func == (lhs: ConnectionAttempt, rhs: ConnectionAttempt) -> Bool {
        return (lhs.peripheral.identifier == rhs.peripheral.identifier)
    }
}
