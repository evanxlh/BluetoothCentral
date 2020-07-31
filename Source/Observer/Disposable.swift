//
//  Disposable.swift
//
//  Created by Evan Xie on 2020/7/16.
//

import Foundation

public final class Disposable {
    
    let dispose: () -> Void
    
    public init(_ dispose: @escaping () -> Void) {
        self.dispose = dispose
    }
    
    deinit {
        dispose()
    }
    
    public func dispose(by disposeBag: DisposeBag) {
        disposeBag.add(self)
    }
}

public final class DisposeBag {
    
    private var lock: NSRecursiveLock
    private var disposables: [Disposable]
    private var isDisposed = false
    
    public init() {
        lock = NSRecursiveLock()
        disposables = [Disposable]()
    }
    
    deinit {
        self.dispose()
    }

    public func add(_ disposable: Disposable) {
        lock.lock()
        defer { lock.unlock() }
        if isDisposed { return }
        
        disposables.append(disposable)
    }

    private func dispose() {
        let disposables = removeDisposables()
        for disposable in disposables {
            disposable.dispose()
        }
    }

    private func removeDisposables() -> [Disposable] {
        lock.lock()
        defer { lock.unlock() }

        let disposables = self.disposables
        self.disposables.removeAll(keepingCapacity: false)
        self.isDisposed = true
        
        return disposables
    }
}
