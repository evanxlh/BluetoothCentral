//
//  BluetoothViewController.swift
//  Demo-iOS
//
//  Created by Evan Xie on 2020/5/28.
//

import UIKit
import CoreBluetooth
import BluetoothCentral

enum BluetoothState {
    case initial
    case establishing
    case failToEstablish
    case ready
}

class BluetoothViewController: UIViewController {

    var manager: BCCentral!
    var peripheral: CBPeripheral! {
        didSet {
            peripheraWrapper = BCPeripheral(peripheral: peripheral)
        }
    }
    
    var state: BluetoothState = .initial
    
    var isConnected: Bool {
        return peripheral.state == .connected
    }
    
    fileprivate var peripheraWrapper: BCPeripheral!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "断开连接并退出", style: .plain, target: self, action: #selector(disconnectAndExit))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "开始建立通信", style: .plain, target: self, action: #selector(establishCommunication))
    }
    
    @objc private func disconnectAndExit() {
        guard isConnected else {
            return
        }
        manager.disconnectPeripheral(peripheral)
    }
    
    @objc private func establishCommunication() {
        updateBluetooth(.establishing)
        KRProgressHUD.showInfo(withMessage: "建立通信中")
        
        peripheraWrapper.discoverService()
    }
    
    func updateBluetooth(_ state: BluetoothState) {
        self.state = state
        if peripheral.name == nil {
            self.title = "蓝牙设备"
        } else {
            self.title = peripheral.name
        }
        
        switch state {
        case .initial:
            break
        case .establishing:
            self.navigationItem.prompt = "正在建立通信"
            self.navigationItem.rightBarButtonItem?.isEnabled = false
        case .failToEstablish:
            self.navigationItem.rightBarButtonItem?.isEnabled = true
            self.navigationItem.prompt = "建立通信失败，可以重试"
        case .ready:
            self.navigationItem.rightBarButtonItem?.isEnabled = false
            self.navigationItem.prompt = "建立通信成功"
        }
    }
    
    func showAlertWithMessage(_ message: String) {
        let alert = UIAlertController(title: "提  示", message: message, preferredStyle: .alert)
        present(alert, animated: true, completion: nil)
    }
    

    @IBAction func queryDeviceInfo(_ sender: UIButton) {
    }
    
}
