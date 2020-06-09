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
    
    @IBOutlet weak var serviceButton: UIButton!
    @IBOutlet weak var logView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.delegate = self
        
        prepareServices()
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
            manager.stopAdvertising()
        } else {
            manager.startAdvertising(composeAdvertisementData())
        }
        
        serviceButton.isSelected = !serviceButton.isSelected
    }
}

fileprivate extension PublishBluetoothServiceVC {
    
    func composeAdvertisementData() -> [String: Any] {
        return [
            CBAdvertisementDataLocalNameKey: "I'm NO.Slave",
            CBAdvertisementDataIsConnectable: true,
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: serviceUUID_1)],
            CBAdvertisementDataTxPowerLevelKey: 200,
            CBAdvertisementDataManufacturerDataKey: "Apple iPhone".data(using: .utf8)!
        ]
    }
    
    func prepareServices() {
        
        characteristics.removeAll()
        
        let data1 = "I'm character 1_1".data(using: .utf8)!
        
        let service1 = CBMutableService(type: CBUUID(string: serviceUUID_1), primary: true)
        
        // Characteristic 如果带初始数据的话，属性必须为 read
        let characteristic1 = CBMutableCharacteristic(type: CBUUID(string: characteristicUUID_1_1), properties: CBCharacteristicProperties.read, value: data1, permissions: .readable)
        let characteristic2 = CBMutableCharacteristic(type: CBUUID(string: characteristicUUID_1_2), properties: CBCharacteristicProperties.write, value: nil, permissions: .readable)
        let characteristic3 = CBMutableCharacteristic(type: CBUUID(string: characteristicUUID_1_3), properties: [.write, .notify], value: nil, permissions: [.writeable])
        characteristics.append(contentsOf: [characteristic1, characteristic2, characteristic3])
        
        service1.characteristics = characteristics
        
        manager.add(service1)
        manager.startAdvertising(composeAdvertisementData())
    }
}

extension PublishBluetoothServiceVC: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("DidUpdateState")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("didReceiveRead: [\(request.characteristic.uuid.uuidString), \(request.offset), \(String(describing: request.value))]")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("didReceiveWrite")
        for request in requests {
            peripheral.respond(to: request, withResult: .success)
            
            if request.characteristic.properties.contains(.notify) {
                let response = "Recevied request: \(request.characteristic.uuid.uuidString)".data(using: .utf8)!
                if !peripheral.updateValue(response, for: request.characteristic as! CBMutableCharacteristic, onSubscribedCentrals: nil) {
                    print("Notify \(request.characteristic.uuid.uuidString) failed")
                }
            }
        }
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("toUpdateSubscribers")
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("DidStartAdvertising, error: \(String(describing: error))")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        print("didAddService")
    }
    
    @available(iOS 11.0, *)
    func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?) {
        print("didOpenChannel, error: \(String(describing: error))")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        print("didPublishL2CAPChannel")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        print("didUnpublishL2CAPChannel")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("didSubscribeTo")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("didUnsubscribeFrom")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        print("willRestoreState")
    }
    
}
