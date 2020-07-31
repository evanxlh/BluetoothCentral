//
//  ScanViewController.swift
//  Demo
//
//  Created by Evan Xie on 2020/5/28.
//

import UIKit
import CoreBluetooth
import BluetoothCentral

class ScanViewController: UITableViewController {
    
    fileprivate let disposeBag = DisposeBag()
    fileprivate var manager: CentralManager!
    fileprivate var discoveries = [PeripheralDiscovery]()
    fileprivate var isScanning = false

    override func viewDidLoad() {
        super.viewDidLoad()
        KRProgressHUD.set(duration: 2.0)
        updateNavigationTitle()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "开始扫描", style: .plain, target: self, action: #selector(startScan))
        manager = CentralManager()
        listenerEvents()
    }
    
    @objc fileprivate func startScan() {
        updateScanningStateTo(true)
        discoveries.removeAll()
        tableView.reloadData()
        
        let filter = CentralManager.ScanFilter(serviceUUIDs: [], isUpdateDuplicatesEnabled: true) { (discovery) -> Bool in
            guard  discovery.localName != nil else {
                return false
            }
            return true
        }
        manager.startScan(withMode: .fixedDuration(5.0), filter: filter, onProgress: { [unowned self] (change) in
            switch change {
            case let .updated(discovery, index):
                self.discoveries[index] = discovery
                self.tableView.reloadRows(at: [IndexPath(item: index, section: 0)], with: .none)
            case let .new(discovery):
                self.discoveries.append(discovery)
                self.tableView.insertRows(at: [IndexPath(item: self.discoveries.count - 1, section: 0)], with: .right)
            }
        }, onCompletion: { [unowned self] (discoveries) in
            
            self.updateScanningStateTo(false)
            if discoveries.isEmpty {
                KRProgressHUD.showInfo(withMessage: "没有发现蓝牙设备，你可重新扫描")
            } else {
                KRProgressHUD.showInfo(withMessage: "扫描完成")
            }
            
        }) { [unowned self] (error) in
            self.updateScanningStateTo(false)
            KRProgressHUD.showError(withMessage: "扫描出错了: \(error.localizedDescription)")
        }
    }
    
    fileprivate func stopScan() {
        manager.stopScan()
        updateScanningStateTo(false)
    }
    
    fileprivate func connectPeripheral(_ peripheral: Peripheral) {
        
        stopScan()
        
        if peripheral.isConnected {
            manager.disconnectPeripheral(peripheral)
            return
        }
        
        manager.connect(withTimeout: 3.0, peripheral: peripheral, onSuccess: { (remotePeripheral) in
            print("Connected \(peripheral) => \(remotePeripheral)")
            let bluetoothVC = self.storyboard!.instantiateViewController(withIdentifier: "BluetoothDeviceViewController") as! BluetoothDeviceViewController
            bluetoothVC.manager = self.manager
            bluetoothVC.peripheral = peripheral
            self.navigationController?.pushViewController(bluetoothVC, animated: true)
            
        }) { (remotePeripheral, error) in
            print("Connected error: \(error) => \(remotePeripheral)")
            KRProgressHUD.showError(withMessage: error.localizedDescription)
        }
    }
    
    fileprivate func updateNavigationTitle() {
        if isScanning {
            self.title = "正在扫描中"
        } else {
            self.title = "Jimu蓝牙设备扫描";
        }
    }
    
    fileprivate func updateScanningStateTo(_ scanning: Bool) {
        isScanning = scanning;
        navigationItem.rightBarButtonItem?.isEnabled = !scanning
        updateNavigationTitle()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveries.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScanTableCell", for: indexPath)
        let discovery = discoveries[indexPath.row]
        cell.textLabel?.text = discovery.localName ?? "无名蓝牙"
        cell.detailTextLabel?.text = "RSSI: \(discovery.rssi)"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        connectPeripheral(discoveries[indexPath.row].peripheral)
    }
    
    private func listenerEvents() {
        
        manager.availabilityEvent.subscribe { [weak self] (availability) in
            switch availability {
            case .available:
                self?.startScan()
            case .unavailable(reason: let reason):
                KRProgressHUD.showError(withMessage: reason.debugDescription)
            }
        }.dispose(by: disposeBag)
        
        manager.peripheralDisconnectEvent.subscribe { [weak self] (peripheral) in
            self?.navigationController?.popToRootViewController(animated: true)
            print("现在还连接的设备: \(String(describing: self?.manager.connectedPeripherals))")
            KRProgressHUD.showMessage("蓝牙[\(String(describing: peripheral.name))]断开连接了!!!")
        }.dispose(by: disposeBag)
    }
}
