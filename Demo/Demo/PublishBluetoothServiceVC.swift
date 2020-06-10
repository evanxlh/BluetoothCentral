//
//  PublishBluetoothServiceVC.swift
//  Demo
//
//  Created by Evan Xie on 2020/6/8.
//

import UIKit
import CoreBluetooth
import BluetoothCentral

class PublishBluetoothServiceVC: UIViewController {
    
    fileprivate let manager =  CBPeripheralManager()
    fileprivate var characteristics = [CBCharacteristic]()
    fileprivate var batteryTimer: DispatchTimer?
    fileprivate var logBuffer = String()
    
    fileprivate var batteryLevelCharacteristic: CBMutableCharacteristic?
    fileprivate var modelNumberCharacteristic: CBMutableCharacteristic?
    fileprivate var manufacturerCharacteristic: CBMutableCharacteristic?
    fileprivate var readCharacteristic: CBMutableCharacteristic?
    fileprivate var writeCharacteristic: CBMutableCharacteristic?
    fileprivate var writeAndNotifyCharacteristic: CBMutableCharacteristic?
    
    @IBOutlet weak var serviceButton: UIButton!
    @IBOutlet weak var logView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.delegate = self
        logView.text = logBuffer
        logView.isEditable = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        manager.stopAdvertising()
    }

    @IBAction func handleBluetoothServiceButtonEvent(_ sender: Any) {
        if manager.state != .poweredOn {
            KRProgressHUD.showError(withMessage: "请打开系统蓝牙")
            return
        }
        
        if serviceButton.isSelected {
            outputLog("stop advertising...")
            manager.stopAdvertising()
        } else {
            outputLog("start advertising...")
            manager.startAdvertising(composeAdvertisementData())
        }
        
        serviceButton.isSelected = !serviceButton.isSelected
    }
}

fileprivate extension PublishBluetoothServiceVC {
    
    func composeAdvertisementData() -> [String: Any] {
        return [
            CBAdvertisementDataLocalNameKey: "I'm NO.1 Slave",
            CBAdvertisementDataIsConnectable: true,
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: dataServiceUUID)],
            CBAdvertisementDataTxPowerLevelKey: 200,
            CBAdvertisementDataManufacturerDataKey: "Apple iPhone".data(using: .utf8)!
        ]
    }
    
    func prepareServices() {
        
        outputLog("Preparing services")
        
        characteristics.removeAll()
        
        let data1 = "I'm just a readable character".data(using: .utf8)!
        
        let service1 = CBMutableService(type: CBUUID(string: dataServiceUUID), primary: true)
        
        // Characteristic 如果带 cache value的话，属性必须为 readonly, 否则会 crash，报错误： 'Characteristics with cached values must be read-only'
        readCharacteristic = CBMutableCharacteristic(type: CBUUID(string: readCharacteristicUUID), properties: CBCharacteristicProperties.read, value: data1, permissions: .readable)
        writeCharacteristic = CBMutableCharacteristic(type: CBUUID(string: writeCharacteristicUUID), properties: CBCharacteristicProperties.write, value: nil, permissions: .readable)
        writeAndNotifyCharacteristic = CBMutableCharacteristic(type: CBUUID(string: writeAndNotifyCharacteristicUUID), properties: [.write, .notify], value: nil, permissions: [.writeable])
        characteristics.append(contentsOf: [readCharacteristic!, writeCharacteristic!, writeAndNotifyCharacteristic!])
        
        service1.characteristics = characteristics
        manager.add(service1)
    }
    
    func updateBatteryLevelPeriodically() {
        
        outputLog("start notify battery level")
        
        batteryTimer = DispatchTimer()
        batteryTimer?.schedule(withTimeInterval: 5, repeats: true, handler: { [weak self] (_) in
            guard let `self` = self else { return }
            let batteryLevel = UInt8(arc4random() % 100)
            if let characteristic = self.batteryLevelCharacteristic {
                self.manager.updateValue(Data([batteryLevel]), for: characteristic, onSubscribedCentrals: nil)
                self.outputLog("notify battery level: \(batteryLevel)")
            }
        })
    }
    
    func outputLog(_ message: String) {
        DispatchQueue.main.async {
            self.logBuffer.append("\(message)\n")
            self.logView.text = self.logBuffer
            print("\(message)\n")
        }
    }
}

extension PublishBluetoothServiceVC: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        outputLog("DidUpdateState: \(peripheral.state.rawValue)")
        
        if peripheral.state == .poweredOn {
            prepareServices()
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        outputLog("didReceiveRead: [\(request.characteristic.uuid.uuidString), \(request.offset), \(String(describing: request.value))]")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            let uuid = request.characteristic.uuid.uuidString
            let message: String?
            if let data = request.characteristic.value {
                message = String(data: data, encoding: .utf8)
            } else {
                message = nil
            }
            outputLog("Receive message from \(uuid): \(String(describing: message))")
            
            if request.characteristic.properties.contains(.write) {
                peripheral.respond(to: request, withResult: .success)
            }
            
            if request.characteristic.properties.contains(.notify) {
                let response = "Recevied request: \(request.characteristic.uuid.uuidString)".data(using: .utf8)!
                if !peripheral.updateValue(response, for: request.characteristic as! CBMutableCharacteristic, onSubscribedCentrals: nil) {
                    outputLog("Notify \(request.characteristic.uuid.uuidString) failed")
                }
            }
        }
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        outputLog("peripheralManagerIsReady toUpdateSubscribers")
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        outputLog("DidStartAdvertising, error: \(String(describing: error))")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        outputLog("didAddService: \(service.uuid.uuidString)")
    }
    
    @available(iOS 11.0, *)
    func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?) {
        outputLog("didOpenChannel, error: \(String(describing: error))")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        outputLog("didPublishL2CAPChannel")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        outputLog("didUnpublishL2CAPChannel")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        outputLog("didSubscribeTo characteristic: \(characteristic.uuid.uuidString)")
        
        if characteristic.uuid.uuidString == batteryLevelCharacteristicUUID {
            updateBatteryLevelPeriodically()
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        outputLog("didUnsubscribeFrom characteristic: \(characteristic.uuid.uuidString)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        outputLog("willRestoreState")
    }
}
