//
//  ScanViewController.swift
//  Demo-iOS
//
//  Created by Evan Xie on 2020/5/28.
//

import UIKit
import CoreBluetooth
import BluetoothCentral

class ScanViewController: UITableViewController {
    
    fileprivate var manager: BCCentral!
    fileprivate var discoveries = [BCDiscovery]()
    fileprivate var isScanning = false

    override func viewDidLoad() {
        super.viewDidLoad()
        KRProgressHUD.set(duration: 2.0)
        updateNavigationTitle()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "开始扫描", style: .plain, target: self, action: #selector(startScan))
        manager = BCCentral()
        manager.delegate = self
    }
    
    @objc fileprivate func startScan() {
        
        updateScanningStateTo(true)
        discoveries.removeAll()
        tableView.reloadData()
        
        manager.startScan(withMode: .fixedDuration(5.0), onProgress: { [unowned self] (discoveries) in
            // 扫描进度回调。每次扫描到新的 jimu 蓝牙设备时，就会触发一次。
            self.discoveries.append(contentsOf: discoveries)
            self.tableView.reloadData()
            
        }, onCompletion: { [unowned self] (discoveries) in
            
            self.updateScanningStateTo(false)
            self.discoveries.removeAll()
            self.discoveries.append(contentsOf: discoveries)
            if discoveries.isEmpty {
                KRProgressHUD.showInfo(withMessage: "没有发现蓝牙设备，你可重新扫描")
            } else {
                KRProgressHUD.showInfo(withMessage: "扫描完成")
            }
            
        }, onError: { [unowned self] error in
            self.updateScanningStateTo(false)
             KRProgressHUD.showError(withMessage: "扫描出错了: \(error.localizedDescription)")
        })
    }
    
    fileprivate func stopScan() {
        manager.stopScan()
        updateScanningStateTo(false)
    }
    
    fileprivate func connectPeripheral(_ peripheral: CBPeripheral) {
        
        stopScan()
        
        manager.connect(withTimeout: 5.0, peripheral: peripheral, onSuccess: {
            let bluetoothVC = self.storyboard!.instantiateViewController(withIdentifier: "BluetoothViewController") as! BluetoothViewController
            bluetoothVC.manager = self.manager
            self.navigationController?.pushViewController(bluetoothVC, animated: true)
        }) { (error) in
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
        cell.textLabel?.text = discovery.localName
        cell.detailTextLabel?.text = "RSSI: \(discovery.rssi)"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        connectPeripheral(discoveries[indexPath.row].peripheral)
    }
}

extension ScanViewController: BCCentralDelegate {
    
    func central(_ centralManager: BCCentral, peripheralDidDisconnect peripheral: CBPeripheral) {
        navigationController?.popToRootViewController(animated: true)
        KRProgressHUD.showMessage("蓝牙[\(String(describing: peripheral.name))]断开连接了!!!")
    }
    
    func central(_ centralManager: BCCentral, availabilityDidUpdate availability: BCAvailability) {
        switch availability {
        case .available:
            startScan()
        case .unavailable(reason: let reason):
            KRProgressHUD.showError(withMessage: reason.debugDescription)
        }
    }
}
