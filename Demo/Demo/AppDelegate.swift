//
//  AppDelegate.swift
//  Demo
//
//  Created by Evan Xie on 2020/5/28.
//

import UIKit


struct TestDataType {
    var cc: UInt8 = 8
    var tag: UInt16 = 1234
    var id: UInt16 = 256
}




extension Data {
    
    init<DataType>(dataType: DataType) {
        var value = dataType
        
        self.init(buffer: UnsafeBufferPointer<DataType>.init(start: &value, count: 1))
    }
    
    init<DataType>(dataTypes: [DataType]) {
        var values = dataTypes
        self.init(buffer: UnsafeBufferPointer<DataType>.init(start: &values, count: values.count))
    }
    
    func toDataType<DataType>() -> DataType? {
        return withUnsafeBytes {
            $0.load(as: DataType.self)
//            $0.baseAddress?.assumingMemoryBound(to: DataType.self).pointee
        }
    }
    
    func toDataTypes<DataType>() -> [DataType] {
        let values = withUnsafeBytes { (pointer) -> [DataType] in
            let buffer = pointer.bindMemory(to: DataType.self)
            return buffer.map { $0 }
        }
        return values
    }
    
    /// 从二进制数据指定偏移位置读出指定类型的数据。
    ///
    /// `DataType` 可以为任意类型(如 UInt16, struct 等)，但要注意 Data 的内存分布情况，否则会出现意想不到的问题。
    func readValue<DataType>(offset: Data.Index) -> DataType? {
        let maxOffset = count - MemoryLayout<DataType>.size
        guard Range(0...maxOffset).contains(offset) else {
            return nil
        }
        
        return withUnsafeBytes {
            $0.baseAddress?.advanced(by: offset).assumingMemoryBound(to: DataType.self).pointee
        }
    }
}


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        var dataTypeInstance = TestDataType()
        let data = Data.init(dataType: dataTypeInstance)
        let instance: TestDataType? = data.toDataType()
        
        return true
    }

}

