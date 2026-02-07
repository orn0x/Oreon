import 'dart:typed_data';

enum ConnectionType { wifi, bluetooth, centralized, decentralized }

class Chat {
  final String identifier;
  final String id;
  final String contactName;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final ConnectionType connectionType;
  final String avatarText;
  final String? avatarUrl;
  final Uint8List? imageBytes;
  final String? deviceId;
  final Uint8List? avatarImageBytes;

  Chat({
    required this.identifier,
    required this.id,
    required this.contactName,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.connectionType,
    required this.avatarText,
    this.avatarUrl,
    this.imageBytes,
    this.deviceId,
    this.avatarImageBytes,
  });

  // Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'id': id,
      'contactName': contactName,
      'lastMessage': lastMessage,
      'timestamp': timestamp.toIso8601String(),
      'unreadCount': unreadCount,
      'connectionType': connectionType.toString(),
      'avatarText': avatarText,
      'avatarUrl': avatarUrl,
      'imageBytes': imageBytes?.toString(),
    };
  }

  // Create from JSON
  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      identifier: json['identifier'],
      id: json['id'],
      contactName: json['contactName'],
      lastMessage: json['lastMessage'],
      timestamp: DateTime.parse(json['timestamp']),
      unreadCount: json['unreadCount'],
      connectionType: _connectionTypeFromString(json['connectionType']),
      avatarText: json['avatarText'],
      avatarUrl: json['avatarUrl'],
    );
  }

  static ConnectionType _connectionTypeFromString(String type) {
    switch (type) {
      case 'ConnectionType.bluetooth':
        return ConnectionType.bluetooth;
      case 'ConnectionType.wifi':
        return ConnectionType.wifi;
      case 'ConnectionType.centralized':
        return ConnectionType.centralized;
      case 'ConnectionType.decentralized':
        return ConnectionType.decentralized;
      default:
        return ConnectionType.bluetooth;
    }
  }

  Chat copyWith({
    String? identifier,
    String? id,
    String? contactName,
    String? lastMessage,
    DateTime? timestamp,
    int? unreadCount,
    ConnectionType? connectionType,
    String? avatarText,
    String? avatarUrl,
    Uint8List? imageBytes,
  }) {
    return Chat(
      identifier: identifier ?? this.identifier,
      id: id ?? this.id,
      contactName: contactName ?? this.contactName,
      lastMessage: lastMessage ?? this.lastMessage,
      timestamp: timestamp ?? this.timestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      connectionType: connectionType ?? this.connectionType,
      avatarText: avatarText ?? this.avatarText,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }
}
