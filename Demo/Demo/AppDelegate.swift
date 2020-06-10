//
//  AppDelegate.swift
//  Demo
//
//  Created by Evan Xie on 2020/5/28.
//

import UIKit
import CoreBluetooth

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print(CBCharacteristicProperties.broadcast)
        print(CBCharacteristicProperties.read)
        print(CBCharacteristicProperties.writeWithoutResponse)
        print(CBCharacteristicProperties.write)
        print(CBCharacteristicProperties.notify)
        print(CBCharacteristicProperties.indicate)
        print(CBCharacteristicProperties.authenticatedSignedWrites)
        print(CBCharacteristicProperties.extendedProperties)
        print(CBCharacteristicProperties.notifyEncryptionRequired)
        print(CBCharacteristicProperties.indicateEncryptionRequired)
        return true
    }

}

