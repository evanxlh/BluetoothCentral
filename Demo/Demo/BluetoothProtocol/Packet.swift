//
//  Packet.swift
//
//  Created by Evan Xie on 2020/6/1.
//

import Foundation

enum PacketError: Swift.Error {
    case badFormat(String)
}

struct Packet {
    
    enum FieldOffset: Int {
        case startBytes = 0
        case cmdId = 1
        case payload = 2
        case checksum = 15
    }
    
    private let _rawData: [UInt8]
    
    static let packetDataLength: Int = 16
    static let startBytesLength: Int = 2
    static let scmdIdLength: Int = 1
    static let payloadLength: Int = 12
    static let checksumLength: Int = 1

    static let highStartByte: UInt8 = 0xFA
    static let lowStartByte: UInt8 = 0xF9
    
    let highStartByte: UInt8
    let lowStartByte: UInt8
    let cmdId: UInt8
    let payload: [UInt8]
    let checksum: UInt8
    
    var rawData: [UInt8] {
        return _rawData
    }

    init(packetData: [UInt8]) {

        _rawData = packetData
        
        if packetData.count != Packet.packetDataLength {
//            throw PacketError.badFormat("Packet: invalid data length")
            print("Packet: invalid data length")
        }

        highStartByte = packetData[0]
        lowStartByte = packetData[1]
        cmdId = packetData[2]
        checksum = packetData[15]
        
        var payload = [UInt8](repeating: 0, count: Packet.payloadLength)
        for index in 2..<15 {
            payload[index - 2] = packetData[index]
        }
        self.payload = payload
        
        if highStartByte != Packet.highStartByte {
//            throw PacketError.badFormat("Packet: invalid start bytes")
            print("Packet: invalid high start bytes")
        }
        
        if lowStartByte != Packet.lowStartByte {
//            throw PacketError.badFormat("Packet: invalid start bytes")
            print("Packet: invalid low start bytes")
        }
        
        let checksum = Packet.caculateChecksumForPayload(payload)
        if self.checksum != checksum {
//            throw PacketError.badFormat("Packet: invalid checksum")
            print("Packet: invalid checksum")
        }
    }
    
    
    
    init(cmdId: UInt8, payload: [UInt8]? = nil) {
        var data = payload ?? [UInt8](repeating: 0, count: Packet.payloadLength)
        data = Packet.padZero(for: data, desiredBytesLength: Packet.payloadLength)
        self.payload = data
        self.cmdId = cmdId
        
        highStartByte = Packet.highStartByte
        lowStartByte = Packet.lowStartByte
        checksum = Packet.caculateChecksumForPayload(self.payload)
        _rawData = [highStartByte, lowStartByte] + [cmdId] + self.payload + [checksum]
    }
}

extension Packet {
    
    static func caculateChecksumForPayload(_ payload: [UInt8]) -> UInt8 {
        guard payload.count == Packet.payloadLength else {
            fatalError("Invalid packet data length")
        }
        
        var checksum: UInt8 = 0
        for index in 0..<Packet.payloadLength {
            checksum = checksum.addingReportingOverflow(payload[index]).partialValue
        }
        return checksum.addingReportingOverflow(0x42).partialValue
    }
    
    static func padZero(for bytes: [UInt8], desiredBytesLength: Int) -> [UInt8] {
        let padCount = desiredBytesLength - bytes.count
        guard padCount > 0 else { return bytes }
        
        var array = bytes
        for _ in 0..<padCount {
            array.append(0)
        }
        return array
    }
}

