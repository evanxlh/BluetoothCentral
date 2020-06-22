//
//  WeakObject.swift
//
//  Created by Evan Xie on 2020/6/22.
//

import Foundation

internal class WeakObject<Object>: Equatable where Object: AnyObject {
    
    weak var object: Object? = nil
    
    init(object: Object) {
        self.object = object
    }
    
    static func == (lhs: WeakObject<Object>, rhs: WeakObject<Object>) -> Bool {
        return lhs.object === rhs.object
    }
}
