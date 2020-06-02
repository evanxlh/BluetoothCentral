//
//  PacketMaker.swift
//
//  Created by Evan Xie on 2020/6/1.
//

import Foundation

enum CommandID: UInt8 {
    case hardwareInfo = 0xA0
    case workingState = 0xA1
    case control = 0xA2
}

struct PacketMaker {
    
    static func queryHardwareInfoCommand() -> Packet {
        return Packet(cmdId: CommandID.hardwareInfo.rawValue)
    }
    
    static func queryWorkingState() -> Packet {
        return Packet(cmdId: CommandID.workingState.rawValue)
    }
}
