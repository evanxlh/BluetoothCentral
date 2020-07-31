//
//  PublishSubject.swift
//
//  Created by Evan Xie on 2020/7/16.
//

import Foundation

public class PublishSubject<Value>: Observable<Value> {
    
    public func asObservable() -> Observable<Value> {
        return self
    }
    
    public func publish(_ value: Value) {
        notifyObservers(value)
    }
}

public class BehaviorSubject<Value>: PublishSubject<Value> {
    
    private var _value: Value
    
    public var value: Value {
        return _value
    }
    
    public init(value: Value, onDispose: @escaping () -> Void = {}) {
        _value = value
        super.init(onDispose)
    }
    
    public override func publish(_ value: Value) {
        _value = value
        super.publish(_value)
    }
}
