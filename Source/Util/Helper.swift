//
//  Helper.swift
//
//  Created by Evan Xie on 2020/5/28.
//

import Foundation

internal enum InternalError: Error {
    case unknown
}

internal func runTaskOnMainThread(_ taskBlock: @escaping () -> Void) {
    if Thread.isMainThread {
        taskBlock()
    } else {
        DispatchQueue.main.async { taskBlock() }
    }
}
