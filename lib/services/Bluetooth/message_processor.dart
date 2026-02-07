import 'dart:convert';

class MessageProcessor {
  // Create a chat message
  Map<String, dynamic> createChatMessage(dynamic data) {
    return {
      'appIdentifier': 'CHAT_APP_V1.0',
      'protocolVersion': '1.0',
      'type': 'chat_message',
      'timestamp': DateTime.now().toIso8601String(),
      'payload': data is String ? {'text': data} : data,
      'checksum': _generateChecksum(data),
      'features': ['text', 'emoji', 'attachments'],
      'encryption': 'none', // or 'aes256' if encrypted
    };
  }
  
  // Create a file transfer message
  Map<String, dynamic> createFileMessage(dynamic data) {
    return {
      'appIdentifier': 'FILE_TRANSFER_V1.0',
      'protocolVersion': '1.0',
      'type': 'file_transfer',
      'timestamp': DateTime.now().toIso8601String(),
      'payload': data,
      'checksum': _generateChecksum(data),
      'features': ['binary', 'chunked'],
    };
  }
  
  // Create a generic message
  Map<String, dynamic> createGenericMessage(dynamic data) {
    return {
      'appIdentifier': 'GENERIC_APP_V1.0',
      'type': 'data',
      'timestamp': DateTime.now().toIso8601String(),
      'payload': data,
    };
  }
  
  // Process incoming message and identify app type
  Map<String, dynamic> processMessage(Map<String, dynamic> jsonData) {
    // Extract app identifier
    String? appIdentifier = jsonData['appIdentifier']?.toString();
    
    // Default result
    Map<String, dynamic> result = {
      'original': jsonData,
      'processedAt': DateTime.now().toIso8601String(),
      'isValid': false,
    };
    
    // Identify app type
    if (appIdentifier != null) {
      result['appType'] = _identifyAppType(appIdentifier, jsonData);
      result['isValid'] = true;
      
      // Extract relevant data based on app type
      switch (result['appType']) {
        case 'chat':
          result = _extractChatData(jsonData, result);
          break;
        case 'file_transfer':
          result = _extractFileData(jsonData, result);
          break;
        default:
          result['data'] = jsonData['payload'];
      }
    } else {
      // Try to infer app type from message structure
      result['appType'] = _inferAppType(jsonData);
      result['isValid'] = true;
    }
    
    // Verify checksum if present
    if (jsonData.containsKey('checksum')) {
      result['checksumValid'] = _verifyChecksum(jsonData);
    }
    
    return result;
  }
  
  // Identify app type from identifier
  String _identifyAppType(String identifier, Map<String, dynamic> data) {
    identifier = identifier.toLowerCase();
    
    if (identifier.contains('chat')) {
      return 'chat';
    } else if (identifier.contains('file') || identifier.contains('transfer')) {
      return 'file_transfer';
    } else if (identifier.contains('sensor') || identifier.contains('iot')) {
      return 'iot';
    } else if (identifier.contains('control') || identifier.contains('command')) {
      return 'control';
    } else if (data.containsKey('type')) {
      return data['type'].toString();
    } else {
      return 'unknown';
    }
  }
  
  // Infer app type from message structure
  String _inferAppType(Map<String, dynamic> data) {
    // Check for chat message structure
    if (data.containsKey('payload')) {
      final payload = data['payload'];
      if (payload is Map) {
        if (payload.containsKey('text') && payload.containsKey('sender')) {
          return 'chat';
        } else if (payload.containsKey('fileName') || payload.containsKey('fileSize')) {
          return 'file_transfer';
        }
      }
    }
    
    // Check for direct chat fields
    if (data.containsKey('message') || data.containsKey('text')) {
      return 'chat';
    }
    
    return 'data';
  }
  
  // Extract chat-specific data
  Map<String, dynamic> _extractChatData(Map<String, dynamic> original, Map<String, dynamic> result) {
    try {
      dynamic payload = original['payload'];
      
      if (payload is Map) {
        result['sender'] = payload['sender'] ?? 'Unknown';
        result['message'] = payload['text'] ?? payload['message'] ?? '';
        result['timestamp'] = payload['timestamp'] ?? original['timestamp'];
        
        // Check for chat-specific features
        if (payload.containsKey('reaction')) {
          result['hasReaction'] = true;
        }
        if (payload.containsKey('attachment')) {
          result['hasAttachment'] = true;
        }
      } else if (payload is String) {
        result['message'] = payload;
        result['sender'] = 'Unknown';
      }
      
      result['isChat'] = true;
      
    } catch (e) {
      print("Error extracting chat data: $e");
    }
    
    return result;
  }
  
  // Extract file transfer data
  Map<String, dynamic> _extractFileData(Map<String, dynamic> original, Map<String, dynamic> result) {
    try {
      dynamic payload = original['payload'];
      
      if (payload is Map) {
        result['fileName'] = payload['fileName'];
        result['fileSize'] = payload['fileSize'];
        result['fileType'] = payload['fileType'] ?? 'unknown';
        result['chunkIndex'] = payload['chunkIndex'];
        result['totalChunks'] = payload['totalChunks'];
      }
      
      result['isFileTransfer'] = true;
      
    } catch (e) {
      print("Error extracting file data: $e");
    }
    
    return result;
  }
  
  // Generate checksum for data integrity
  String _generateChecksum(dynamic data) {
    String dataString = data is String ? data : json.encode(data);
    
    int checksum = 0;
    for (int i = 0; i < dataString.length; i++) {
      checksum = (checksum + dataString.codeUnitAt(i)) & 0xFFFF;
    }
    
    return checksum.toRadixString(16).padLeft(4, '0');
  }
  
  // Verify checksum
  bool _verifyChecksum(Map<String, dynamic> data) {
    if (!data.containsKey('checksum') || !data.containsKey('payload')) {
      return false;
    }
    
    String expectedChecksum = data['checksum'].toString();
    String calculatedChecksum = _generateChecksum(data['payload']);
    
    return expectedChecksum == calculatedChecksum;
  }
  
  // Check if message is from a chat app
  bool isChatMessage(Map<String, dynamic> message) {
    if (message['appType'] == 'chat') {
      return true;
    }
    
    if (message['isChat'] == true) {
      return true;
    }
    
    // Check message structure
    if (message.containsKey('message') && message.containsKey('sender')) {
      return true;
    }
    
    return false;
  }
}