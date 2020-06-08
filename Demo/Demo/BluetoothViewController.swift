//
//  BluetoothViewController.swift
//  Demo
//
//  Created by Evan Xie on 2020/5/28.
//

import UIKit
import BluetoothCentral

class BluetoothViewController: UIViewController {

    var manager: CentralManager!
    var peripheral: Peripheral!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "退出", style: .plain, target: self, action: #selector(disconnectAndExit))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "建立通信", style: .plain, target: self, action: #selector(establishCommunication))
    }
    
    @objc private func disconnectAndExit() {
        manager.disconnectPeripheral(peripheral)
    }
    
    @objc private func establishCommunication() {
        KRProgressHUD.showInfo(withMessage: "建立通信中")
        
        let service = ServiceInterested(serviceUUID: "SSSSAAA", characteristicUUIDs: ["CCCCAAAA"])
        peripheral.startDataChannel([service], successHandler: {
            
        }) { (error) in
            
        }
    }
    
    func showAlertWithMessage(_ message: String) {
        let alert = UIAlertController(title: "提  示", message: message, preferredStyle: .alert)
        present(alert, animated: true, completion: nil)
    }

}
