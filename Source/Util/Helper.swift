//
//  Helper.swift
//  UniversalBluetooth-iOS
//
//  Created by Evan Xie on 2020/5/28.
//

import Foundation

internal func runTaskOnMainThread(_ taskBlock: @escaping () -> Void) {
    if Thread.isMainThread {
        taskBlock()
    } else {
        DispatchQueue.main.async { taskBlock() }
    }
}
