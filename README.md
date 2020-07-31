# BluetoothCetral
Swift 实现的主设备端的蓝牙通信框架， 支持 扫描、连接管理以及与从设备间的通信。



## CentralManager

负责蓝牙设备的扫描、连接管理，以及系统蓝牙授权信息的状态更新。

### 创建

```swift
class ScanViewController: UITableViewController {
    
    fileprivate lazy var manager: CentralManager = {
        return CentralManager()
    }()
  
    fileprivate var discoveries = [PeripheralDiscovery]()

    override func viewDidLoad() {
        super.viewDidLoad()
        listenEvents()
    }
}
```



### 扫描

扫描可以指定 `filter`, 也可以不指定。可以指定扫描时长，也可以不指定。不过不指定扫找时长，则由开发者主动调用 `manager.stopScan()` 停止扫描。

```swift
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
    if discoveries.isEmpty {
			 // 没有发现蓝牙设备
    } else {
       // 扫描完成
    }
}) { (error) in
    // 扫描出错了
}
```



### 连接

*CentralManager* 支持多连接，已连接上的设备可以通过 *CentralManager* 的 `connectedPeripherals` 来获取。通过调用 `disconnectPeripheral` 来断开连接。 

```swift
manager.connect(withTimeout: 3.0, peripheral: peripheral, onSuccess: { (remotePeripheral) in
	// 已连接上
}) { (remotePeripheral, error) in
  // 连接失败
}
```



### 事件监听

#### 蓝牙状态监听

```swift
manager.availabilityEvent.subscribe { [weak self] (availability) in
    switch availability {
    case .available:
        self?.startScan()
    case .unavailable(reason: let reason):
        // 收到蓝牙不可用的事件
    }
}.dispose(by: disposeBag)
```



#### 蓝牙断开事件监听

```swift
manager.peripheralDisconnectEvent.subscribe { [weak self] (peripheral) in
  // 收到蓝牙断开事件
}.dispose(by: disposeBag)
```



## 蓝牙从设备通信

当蓝牙设备连接成功后，我们就得到了 `Peripheral` 对象，通过它，我们就可以完成蓝牙服务的准备和数据通信了。

### 蓝牙服务准备

准备蓝牙服务可以指定你感兴趣的服务，或者默认将蓝牙设备拥有的所有服务都准备好。建议只开启需要的服务，这样可以节省蓝牙设备的资源。

```swift
peripheral.prepareServicesToReady(successHandler: { (serviceInfoMap) in
	// 蓝牙服务准备就绪，接下来就可以直接通信了
}) { (error) in
 	// 蓝牙服务准备失败，建议断开蓝牙或再次尝试
}
```

### 给蓝牙设备发送数据

将数据发送到指定的 `characteristic`，*Peripheral* 支持任意长度的数据，数据长度太大的话，会自动分包传送。

```swift
do {
    try peripheral.writeData("Hello, I'm a write characteristic".data(using: .utf8)!, toCharacteristic: writeCharacteristicUUID)
} catch {
    // Error
}
```

### 接收蓝牙设备的数据

接收数据需要实现 `PeripheralReceiveDataDelegate`，然后通过 `characteristicUUID` 来区分是哪个 *Characteristic* 传过来的数据。

```swift
final class BluetoothInteractor: PeripheralReceiveDataDelegate {

 func peripheralDidRecevieCharacteristicData(_ peripheral: Peripheral, data: Data, characteristicUUID: String) {
    // 根据协议来组包和解包
	}
}
```

