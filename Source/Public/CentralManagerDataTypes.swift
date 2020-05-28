//
//  CentralManagerDataTypes.swift

//  Created by Evan Xie on 2/26/20.
//

import Foundation
import CoreBluetooth

public extension CentralManager {
    
    // MARK: - Datatype Definition
    
    typealias ScanProgressHandler = ((_ newDiscoveries: [Discovery]) -> Void)
    typealias ScanCompletionHandler = (_ result: Result<[Discovery], Error>) -> Void
    typealias ConnectCompletionHandler = (_ peripheral: CBPeripheral, _ result: Result<Void, Error>) -> Void
    typealias DisconnectedEventHandler = (CBPeripheral) -> Void
    
    enum ScanMode {
        case infinitely
        case fixedDuration(TimeInterval)
    }
    
    enum Error: Swift.Error {
        case internalError(Swift.Error)
    }
    
    /// 扫描蓝牙设备过滤器
    struct ScanFilter {
        
        public typealias CustomFilterHandler = (Discovery) -> Bool
        
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
    
}
