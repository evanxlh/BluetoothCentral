//
//  CentralStateMachine.swift

//  Created by Evan Xie on 2/25/20.
//

import Foundation

/// CentralManager 状态机，集中管理各种行为与状态，保证行为只在正确的状态下被触发。
internal final class CentralStateMachine {
    
    fileprivate var _state = State.initialized
    
    // MARK: - Accessible Within Framework
    
    enum Error: Swift.Error, CustomDebugStringConvertible {
        case transitioning(currentState: State, validStates: [State])
        
        var debugDescription: String {
            switch self {
            case let .transitioning(currentState: state, validStates: validStates):
                return "当前状态: \(state), 有效状态集为: \(validStates)"
            }
        }
    }

    enum State {
        case initialized
        case available
        case unavailable(reason: UnavailabilityReason)
        case scanning
    }

    enum Operation {
        case setUnavailable(reason: UnavailabilityReason)
        case setAvailable
        case scan
        case connect
    }
    
    var state: State {
        return _state
    }

    func validateOperationCanBeExecuted(_ Operation: Operation) throws {
        switch Operation {
        case .setAvailable:
            handleSetAvailable()
        case let .setUnavailable(reason):
            handleSetUnavailable(reason: reason)
        case .scan:
            try handleScan()
        case .connect:
            try handleConnect()
        }
    }
    
}

fileprivate extension CentralStateMachine {
    
    // MARK: - Private Functions
    
    /// 在任何状态下，都可以触发将状态更新为 `available` 的行为。
    func handleSetAvailable() {
        _state = .available
    }

    /// 在任何状态下，都可以触发将状态更新为 `unavailable` 的行为。
    func handleSetUnavailable(reason: UnavailabilityReason) {
        _state = .unavailable(reason: reason)
    }

    /// 只有在 `available` 状态下，才可以触发 `scan` 行为。
    func handleScan() throws {
        switch state {
        case .available:
            _state = .scanning
        default:
            Logger.debug("系统蓝牙还未打开，当前状态为: \(_state)")
            throw Error.transitioning(currentState: state, validStates: [.available])
        }
    }

    /// 只有在 `available` 或 `scanning` 状态下，才可以触发 `connect` 行为。
    func handleConnect() throws {
        switch state {
        case .available, .scanning:
            break
        default:
            throw Error.transitioning(currentState: state, validStates:  [.available, .scanning])
        }
    }
    
}
