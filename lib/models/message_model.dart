enum ConnectionType {
  wifi,
  bluetooth,
  centralized,
  decentralized,
}

class MessageBluetooth {
  final String id;
  final String sender;
  final String content;
  final DateTime timestamp;
  final bool isOutgoing;

  MessageBluetooth({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.isOutgoing,
  });

  factory MessageBluetooth.fromJson(Map<String, dynamic> json) {
    return MessageBluetooth(
      id: json['id'] ?? '',
      sender: json['sender'] ?? '',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isOutgoing: json['isOutgoing'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isOutgoing': isOutgoing,
    };
  }
}


enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

enum MessageType {
  text,
  image,
  file,
  location,
}