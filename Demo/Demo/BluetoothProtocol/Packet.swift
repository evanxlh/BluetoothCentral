//
//  Packet.swift
//
//  Created by Evan Xie on 2020/6/1.
//

import Foundation

struct Packet {
    
    static var startBytes: Data = Data([0xFA, 0xF9])
    
    var header: Data
    
    var payload: Data
    
    var checksum: Data {
        return Data()
    }
}
