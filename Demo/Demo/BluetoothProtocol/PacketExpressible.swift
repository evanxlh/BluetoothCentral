//
//  Packet.swift
//
//  Created by Evan Xie on 2020/6/1.
//

import Foundation

public protocol PacketExpressible {
    
    static var startBytes: Data { get }
    
    var header: Data { get set }
    var payload: Data { get set }
    var checksum: Data { get }
    
    var rawData: Data { get }
}

extension PacketExpressible {
    
    var rawData: Data {
        return Self.startBytes + header + payload + checksum
    }
}
