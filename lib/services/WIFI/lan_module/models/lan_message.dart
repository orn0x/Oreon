/// LAN Message Model
///
/// Represents a message received from another device on the LAN.
/// Contains message content, sender information, and timestamp.

class LanMessage {
  /// Unique identifier for this message
  final String id;

  /// Name of the sender device
  final String senderName;

  /// IP address of the sender device
  final String senderIp;

  /// The message content
  final String content;

  /// Timestamp when the message was created
  final DateTime timestamp;

  /// Creates a new LAN message instance
  ///
  /// [id] - Unique message identifier
  /// [senderName] - Human-readable name of the sender
  /// [senderIp] - IP address of the sender
  /// [content] - The message text content
  /// [timestamp] - When the message was created (defaults to now)
  LanMessage({
    required this.id,
    required this.senderName,
    required this.senderIp,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Converts the message to a JSON representation
  Map<String, dynamic> toJson() => {
    'id': id,
    'senderName': senderName,
    'senderIp': senderIp,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Creates a message from JSON
  factory LanMessage.fromJson(Map<String, dynamic> json) => LanMessage(
    id: json['id'] as String,
    senderName: json['senderName'] as String,
    senderIp: json['senderIp'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanMessage && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'LanMessage(from: $senderName, content: $content, time: $timestamp)';

  /// Creates a copy of this message with optional field overrides
  LanMessage copyWith({
    String? id,
    String? senderName,
    String? senderIp,
    String? content,
    DateTime? timestamp,
  }) => LanMessage(
    id: id ?? this.id,
    senderName: senderName ?? this.senderName,
    senderIp: senderIp ?? this.senderIp,
    content: content ?? this.content,
    timestamp: timestamp ?? this.timestamp,
  );
}
