//
//  Observable.swift
//
//  Created by Evan Xie on 2020/7/16.
//

import Foundation

public class Observable<Value> {
    
    public typealias Observer = (Value) -> Void
    
    private var uniqueID = (0...).makeIterator()
    private let lock = NSRecursiveLock()
    private var onDispose: () -> Void
    
    fileprivate var observers: [Int: (Observer, DispatchQueue?)] = [:]
    
    public init(_ onDispose: @escaping () -> Void = {}) {
        self.onDispose = onDispose
    }
    
    public func subscribe(observer: @escaping Observer, on queue: DispatchQueue = .main) -> Disposable {
        lock.lock()
        defer { lock.unlock() }
        
        let id = uniqueID.next()!
        observers[id] = (observer, queue)
        
        let disposable = Disposable { [weak self] in
            self?.observers[id] = nil
            self?.onDispose()
        }
        
        return disposable
    }
}

extension Observable {
    
    func notifyObservers(_ value: Value) {
        observers.forEach {
            let observer = $0.value.0
            if let queue = $0.value.1 {
                queue.async { observer(value) }
            } else {
                observer(value)
            }
        }
    }
}
