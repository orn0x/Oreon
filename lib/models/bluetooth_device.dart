class BluetoothDeviceModel {
  final String address;
  final String name;
  final bool isConnected;
  final int? rssi;
  final String appIdentifier;

  BluetoothDeviceModel({
    required this.address,
    required this.name,
    required this.isConnected,
    this.rssi,
    required this.appIdentifier,
  });

  @override
  String toString() => 'BluetoothDevice(address: $address, name: $name, isConnected: $isConnected, rssi: $rssi, appIdentifier: $appIdentifier)';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDeviceModel &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}
