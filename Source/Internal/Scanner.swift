//
//  Scanner.swift
//
//  Created by Evan Xie on 2/24/20.
//

import Foundation
import CoreBluetooth

internal extension Scanner {
    
    // MARK: - Datatype Definition
    
    typealias ScanCompletionHandler = (_ result: Result<[Discovery], Error>) -> Void
    
    enum Error: Swift.Error {
        case busy
    }
    
    fileprivate enum State: Int {
        case idle
        case scanning
    }
}

internal final class Scanner {

    // MARK: - Internal Stuff

    fileprivate var state = State.idle
    fileprivate var centralManager: CBCentralManager
    
    fileprivate var scanningTimer: Timer?
    fileprivate var discoveries = [Discovery]()
    fileprivate var progressHandler: CentralManager.ScanProgressHandler?
    fileprivate var completionHandler: ScanCompletionHandler?
    
    // MARK: - Accessible Within Framework
    
    var filter: CentralManager.ScanFilter
    
    init(manager: CBCentralManager, filter: CentralManager.ScanFilter) {
        self.filter = filter
        self.centralManager = manager
    }
    
    func start(withMode mode: CentralManager.ScanMode, progressHandler: CentralManager.ScanProgressHandler? = nil, completionHandler: @escaping ScanCompletionHandler) throws {
        do {
            try transitionToScanningState()
            self.progressHandler = progressHandler
            self.completionHandler = completionHandler
            
            let options = [CBCentralManagerScanOptionAllowDuplicatesKey: filter.isUpdateDuplicatesEnabled]
            centralManager.scanForPeripherals(withServices: filter.serviceUUIDs, options: options)
            processWorkingMode(mode)
        } catch let error {
            throw error
        }
    }

    func stop() {
        guard state == .scanning else { return }
        endScan()
    }

}

fileprivate extension Scanner {
    
    // MARK: - Private Functions
    
    func processWorkingMode(_ mode: CentralManager.ScanMode) {
        switch mode {
        case .infinitely:
            return
        case .fixedDuration(let duration):
            guard duration > 0.001 else { return }
            startScanningTimer(duration)
        }
    }
    
    /// 开始扫描计时，扫描时间到，就停止扫描。
    func startScanningTimer(_ duration: TimeInterval) {
        guard duration > 0 else { return }
        
        if #available(iOS 10.0, *) {
            scanningTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false, block: { [weak self] _ in
                self?.endScan()
            })
        } else {
            scanningTimer = Timer.scheduledTimer(timeInterval: duration, target: self, selector: #selector(endScan), userInfo: nil, repeats: false)
        }
    }
    
    @objc func endScan() {
        invalidateScanningTimer()
        centralManager.stopScan()
        
        let discoveries = self.discoveries
        self.discoveries.removeAll()
        state = .idle
        completionHandler?(.success(discoveries))
    }
    
    func invalidateScanningTimer() {
        if let timer = scanningTimer {
            timer.invalidate()
            scanningTimer = nil
        }
    }
    
    func transitionToScanningState() throws {
        guard state == .idle else {
            throw Error.busy
        }
        state = .scanning
    }
    
}

extension Scanner: CentralManagerDiscoveryDelegate {
    
    // MARK: - CentralManagerDiscoveryDelegate Implementation
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        guard state == .scanning else { return }
        
        let signalStrength = rssi.intValue
        let discovery = Discovery(advertisementData: advertisementData, peripheral: peripheral, rssi: signalStrength)
        guard let filter = self.filter.customFilter, filter(discovery) else {
            return
        }
        
        // 如果扫描暂存数组中包含了已发现的蓝牙设备，则更新已有蓝牙设备信息。反之，则添加一个新记录。
        if let existIndex = discoveries.firstIndex(of: discovery) {
            discoveries[existIndex] = discovery
        } else {
            discoveries.append(discovery)
        }
        
        progressHandler?([discovery])
    }
}
