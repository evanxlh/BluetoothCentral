//
//  BluetoothDeviceViewController.swift
//  Demo
//
//  Created by Evan Xie on 2020/5/28.
//

import UIKit
import BluetoothCentral

class BluetoothDeviceViewController: UIViewController {

    var manager: CentralManager!
    var peripheral: Peripheral!
    @IBOutlet weak var logView: UITextView!
    
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
        
        let service = ServiceInterested(serviceUUID: serviceUUID_1, characteristicUUIDs: [characteristicUUID_1_1, characteristicUUID_1_2, characteristicUUID_1_3])
        peripheral.startDataChannel([service], successHandler: { (serviceInfos) in
            
        }) { (error) in
            
        }
    }
    
    @IBAction func read1(_ sender: Any) {
        
    }
    
    @IBAction func write1(_ sender: Any) {
        try? peripheral.sendData("Hello, Master command 1_1".data(using: .utf8)!, toCharacteristic: characteristicUUID_1_1)
    }
    @IBAction func read2(_ sender: Any) {
    }
    
    @IBAction func write2(_ sender: Any) {
        try? peripheral.sendData("Hello, Master command 1_2".data(using: .utf8)!, toCharacteristic: characteristicUUID_1_2)
    }
    
    
    @IBAction func read3(_ sender: Any) {
    }
    
    @IBAction func write3(_ sender: Any) {
        try? peripheral.sendData("Hello, Master command 1_3".data(using: .utf8)!, toCharacteristic: characteristicUUID_1_3)
    }
    
    func showAlertWithMessage(_ message: String) {
        let alert = UIAlertController(title: "提  示", message: message, preferredStyle: .alert)
        present(alert, animated: true, completion: nil)
    }

}
