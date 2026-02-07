enum ConnectionType {
  wifi,
  bluetooth,
  centralized,
  decentralized,
}

class Message {
  final String identifier;
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isFromMe;
  bool isRead;
  MessageStatus status;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final MessageType type;

  Message({
    required this.identifier,
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isFromMe,
    required this.isRead,
    required this.status,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.type = MessageType.text,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isFromMe': isFromMe,
      'isRead': isRead,
      'status': status.toString(),
      'imageUrl': imageUrl,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'type': type.toString(),
    };
  }

  // Create from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      identifier : json['identifier'],
      id: json['id'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      isFromMe: json['isFromMe'],
      isRead: json['isRead'],
      status: _statusFromString(json['status']),
      imageUrl: json['imageUrl'],
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      type: _typeFromString(json['type']),
    );
  }

  static MessageStatus _statusFromString(String status) {
    switch (status) {
      case 'MessageStatus.sending':
        return MessageStatus.sending;
      case 'MessageStatus.sent':
        return MessageStatus.sent;
      case 'MessageStatus.delivered':
        return MessageStatus.delivered;
      case 'MessageStatus.read':
        return MessageStatus.read;
      case 'MessageStatus.failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  static MessageType _typeFromString(String type) {
    switch (type) {
      case 'MessageType.text':
        return MessageType.text;
      case 'MessageType.image':
        return MessageType.image;
      case 'MessageType.file':
        return MessageType.file;
      case 'MessageType.location':
        return MessageType.location;
      default:
        return MessageType.text;
    }
  }

  // Create a copy with updated fields
  Message copyWith({
    String? identifier,
    String? id,
    String? text,
    DateTime? timestamp,
    bool? isFromMe,
    bool? isRead,
    MessageStatus? status,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    MessageType? type,
  }) {
    return Message(
      identifier: identifier ?? this.identifier,
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isFromMe: isFromMe ?? this.isFromMe,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      type: type ?? this.type,
    );
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