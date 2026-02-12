/// LAN Device Model
///
/// Represents a discovered device on the local network.
/// Contains device identification and connection information.

class LanDevice {
  /// Unique identifier (device name) for this device
  final String id;

  /// Human-readable name of the device
  final String name;

  /// IP address of the device on the local network
  final String ipAddress;

  /// TCP port the device is listening on
  final int port;

  /// Timestamp when this device was discovered
  final DateTime discoveredAt;

  /// Whether this is the local device itself
  bool get isLocal => isLocalDevice;

  /// Internal flag to mark local device
  final bool isLocalDevice;

  /// Creates a new LAN device instance
  ///
  /// [id] - Device identifier (typically device name)
  /// [name] - Human-readable device name
  /// [ipAddress] - IP address on the local network
  /// [port] - TCP port for connection
  /// [discoveredAt] - When the device was discovered (defaults to now)
  /// [isLocalDevice] - Whether this represents the local device (defaults to false)
  LanDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    DateTime? discoveredAt,
    this.isLocalDevice = false,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  /// Converts the device to a JSON representation
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ipAddress': ipAddress,
    'port': port,
    'discoveredAt': discoveredAt.toIso8601String(),
    'isLocalDevice': isLocalDevice,
  };

  /// Creates a device from JSON
  factory LanDevice.fromJson(Map<String, dynamic> json) => LanDevice(
    id: json['id'] as String,
    name: json['name'] as String,
    ipAddress: json['ipAddress'] as String,
    port: json['port'] as int,
    discoveredAt: DateTime.parse(json['discoveredAt'] as String),
    isLocalDevice: json['isLocalDevice'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ipAddress == other.ipAddress &&
          port == other.port;

  @override
  int get hashCode => Object.hash(id, ipAddress, port);

  @override
  String toString() => 'LanDevice(name: $name, ip: $ipAddress:$port)';

  /// Creates a copy of this device with optional field overrides
  LanDevice copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? port,
    DateTime? discoveredAt,
    bool? isLocalDevice,
  }) => LanDevice(
    id: id ?? this.id,
    name: name ?? this.name,
    ipAddress: ipAddress ?? this.ipAddress,
    port: port ?? this.port,
    discoveredAt: discoveredAt ?? this.discoveredAt,
    isLocalDevice: isLocalDevice ?? this.isLocalDevice,
  );
}
