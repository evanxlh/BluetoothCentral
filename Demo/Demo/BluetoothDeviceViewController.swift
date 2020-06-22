//
//  BluetoothDeviceViewController.swift
//  Demo
//
//  Created by Evan Xie on 2020/5/28.
//

import UIKit
import BluetoothCentral

class BluetoothDeviceViewController: UIViewController {
    
    fileprivate var logBuffer = String()
    
    var manager: CentralManager!
    var peripheral: Peripheral!
    
    @IBOutlet weak var logView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        logView.text = logBuffer
        logView.isEditable = false
        
        peripheral.receiveDataDelegate = self
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "退出", style: .plain, target: self, action: #selector(disconnectAndExit))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "开启蓝牙服务", style: .plain, target: self, action: #selector(prepareServicesToRead))
    }
    
    func outputLog(_ message: Any) {
        DispatchQueue.main.async {
            self.logBuffer.append("\(message)\n")
            self.logView.text = self.logBuffer
            print("\(message)\n")
        }
    }
    
    @objc private func disconnectAndExit() {
        manager.disconnectPeripheral(peripheral)
    }
    
    @objc private func prepareServicesToRead() {
        KRProgressHUD.showInfo(withMessage: "开启蓝牙服务中...")
        
//        let service = ServiceInterested(serviceUUID: dataServiceUUID, characteristicUUIDs: [readCharacteristicUUID, writeCharacteristicUUID, writeAndNotifyCharacteristicUUID])
        peripheral.prepareServicesToReady([], successHandler: { (serviceInfos) in
            self.outputLog(serviceInfos.description)
        }) { (error) in
            
        }
    }
    
    @IBAction func readFromReadCharacteristic(_ sender: Any) {
        peripheral.readData(from: readCharacteristicUUID) { (error) in
            
        }
    }
    
    @IBAction func writeToReadCharacteristic(_ sender: Any) {
        outputLog("send: Hello, I'm a just read characteristic")
        
        do {
            try peripheral.writeData("Hello, I'm a just read characteristic".data(using: .utf8)!, toCharacteristic: readCharacteristicUUID)
        } catch {
            outputLog(error)
        }
    }
    
    @IBAction func readFromWriteCharacteristic(_ sender: Any) {
        peripheral.readData(from: writeCharacteristicUUID) { (error) in
            
        }
    }
    
    @IBAction func writeToWriteCharacteristic(_ sender: Any) {
        do {
            outputLog("send: Hello, I'm a write characteristic")
            try peripheral.writeData("Hello, I'm a write characteristic".data(using: .utf8)!, toCharacteristic: writeCharacteristicUUID)
        } catch {
            outputLog(error)
        }
    }
    
    
    @IBAction func readFromWriteAndNotifiyCharacteristic(_ sender: Any) {
        peripheral.readData(from: writeAndNotifyCharacteristicUUID) { (error) in
            
        }
    }
    
    @IBAction func writeToWriteAndNotifiyCharacteristic(_ sender: Any) {
        do {
            outputLog("send: Hello, I'm write and notify characteristic")
            try peripheral.writeData("Hello, I'm write and notify characteristic".data(using: .utf8)!, toCharacteristic: writeAndNotifyCharacteristicUUID)
        } catch {
            outputLog(error)
        }
    }
    
    func showAlertWithMessage(_ message: String) {
        let alert = UIAlertController(title: "提  示", message: message, preferredStyle: .alert)
        present(alert, animated: true, completion: nil)
    }
    
}

extension BluetoothDeviceViewController: PeripheralReceiveDataDelegate {
    
    func peripheralDidRecevieCharacteristicData(_ peripheral: Peripheral, data: Data, characteristicUUID: String) {
        outputLog("Received data from \(characteristicUUID): \(String(describing: String(data: data, encoding: .utf8)))")
    }
    
}
