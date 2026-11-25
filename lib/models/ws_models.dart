import 'json_parsers.dart';
import 'user_role.dart';

/// Connection and authentication lifecycle states for the WebSocket client.
enum WsConnectionState {
  disconnected,
  connecting,
  authenticating,
  authenticated,
  error,
}

/// Base class for all typed WebSocket messages emitted by `ws_server.php`.
sealed class WsEvent {
  const WsEvent(this.type);

  final String type;

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    final type = JsonParsers.parseString(json['type']);
    switch (type) {
      case 'connected':
        return WsConnectedEvent.fromJson(json);
      case 'auth_ok':
        return WsAuthOkEvent.fromJson(json);
      case 'auth_error':
        return WsAuthErrorEvent.fromJson(json);
      case 'chat_message':
        return WsChatMessageEvent.fromJson(json);
      case 'typing':
        return WsTypingEvent.fromJson(json);
      case 'webrtc_signal':
        return WsWebRtcSignalEvent.fromJson(json);
      case 'triage_broadcast':
        return WsTriageBroadcastEvent.fromJson(json);
      default:
        return WsUnknownEvent(type: type, payload: json);
    }
  }
}

class WsConnectedEvent extends WsEvent {
  const WsConnectedEvent({
    required this.authRequired,
    required this.timestamp,
  }) : super('connected');

  final bool authRequired;
  final String timestamp;

  factory WsConnectedEvent.fromJson(Map<String, dynamic> json) {
    return WsConnectedEvent(
      authRequired: JsonParsers.parseBool(json['auth_required'], fallback: true),
      timestamp: JsonParsers.parseString(json['timestamp']),
    );
  }
}

class WsAuthOkEvent extends WsEvent {
  const WsAuthOkEvent({
    required this.role,
    required this.userId,
    required this.expiresAt,
  }) : super('auth_ok');

  final UserRole? role;
  final int userId;
  final int expiresAt;

  factory WsAuthOkEvent.fromJson(Map<String, dynamic> json) {
    return WsAuthOkEvent(
      role: UserRole.tryFromWire(JsonParsers.parseNullableString(json['role'])),
      userId: JsonParsers.parseInt(json['user_id']),
      expiresAt: JsonParsers.parseInt(json['expires_at']),
    );
  }
}

class WsAuthErrorEvent extends WsEvent {
  const WsAuthErrorEvent({
    required this.message,
  }) : super('auth_error');

  final String message;

  factory WsAuthErrorEvent.fromJson(Map<String, dynamic> json) {
    return WsAuthErrorEvent(
      message: JsonParsers.parseString(json['message']),
    );
  }
}

/// Chat payload matching `ws_server.php` `chat_message.message`.
class WsChatMessage {
  const WsChatMessage({
    required this.channelKey,
    required this.senderRole,
    required this.senderId,
    required this.senderName,
    required this.messageText,
    required this.messageType,
    required this.createdAt,
  });

  final String channelKey;
  final String senderRole;
  final int senderId;
  final String senderName;
  final String messageText;
  final String messageType;
  final String createdAt;

  UserRole? get parsedSenderRole => UserRole.tryFromWire(senderRole);

  factory WsChatMessage.fromJson(Map<String, dynamic> json) {
    return WsChatMessage(
      channelKey: JsonParsers.parseString(json['Channel_Key']),
      senderRole: JsonParsers.parseString(json['Sender_Role']),
      senderId: JsonParsers.parseInt(json['Sender_ID']),
      senderName: JsonParsers.parseString(json['Sender_Name']),
      messageText: JsonParsers.parseString(json['Message_Text']),
      messageType:
          JsonParsers.parseString(json['Message_Type'], fallback: 'text'),
      createdAt: JsonParsers.parseString(json['Created_At']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Channel_Key': channelKey,
      'Sender_Role': senderRole,
      'Sender_ID': senderId,
      'Sender_Name': senderName,
      'Message_Text': messageText,
      'Message_Type': messageType,
      'Created_At': createdAt,
    };
  }
}

class WsChatMessageEvent extends WsEvent {
  const WsChatMessageEvent({
    required this.channelKey,
    required this.message,
  }) : super('chat_message');

  final String channelKey;
  final WsChatMessage message;

  factory WsChatMessageEvent.fromJson(Map<String, dynamic> json) {
    return WsChatMessageEvent(
      channelKey: JsonParsers.parseString(json['channel_key']),
      message: WsChatMessage.fromJson(JsonParsers.parseMap(json['message'])),
    );
  }
}

class WsTypingEvent extends WsEvent {
  const WsTypingEvent({
    required this.channelKey,
    required this.senderName,
    required this.senderRole,
  }) : super('typing');

  final String channelKey;
  final String senderName;
  final String senderRole;

  factory WsTypingEvent.fromJson(Map<String, dynamic> json) {
    return WsTypingEvent(
      channelKey: JsonParsers.parseString(json['channel_key']),
      senderName: JsonParsers.parseString(json['sender_name']),
      senderRole: JsonParsers.parseString(json['sender_role']),
    );
  }
}

class WsWebRtcSignalEvent extends WsEvent {
  const WsWebRtcSignalEvent({
    required this.signalType,
    required this.bookingId,
    this.callId,
    required this.callType,
    required this.senderRole,
    required this.senderName,
    this.payload,
  }) : super('webrtc_signal');

  final String signalType;
  final int bookingId;
  final Object? callId;
  final String callType;
  final String senderRole;
  final String senderName;
  final Object? payload;

  factory WsWebRtcSignalEvent.fromJson(Map<String, dynamic> json) {
    return WsWebRtcSignalEvent(
      signalType: JsonParsers.parseString(json['signal_type']),
      bookingId: JsonParsers.parseInt(json['booking_id']),
      callId: json['call_id'],
      callType: JsonParsers.parseString(json['call_type'], fallback: 'video'),
      senderRole: JsonParsers.parseString(json['sender_role']),
      senderName: JsonParsers.parseString(json['sender_name']),
      payload: json['payload'],
    );
  }
}

class WsTriageBroadcastEvent extends WsEvent {
  const WsTriageBroadcastEvent({
    required this.timestamp,
    this.summary,
  }) : super('triage_broadcast');

  final String timestamp;
  final Object? summary;

  factory WsTriageBroadcastEvent.fromJson(Map<String, dynamic> json) {
    return WsTriageBroadcastEvent(
      timestamp: JsonParsers.parseString(json['timestamp']),
      summary: json['summary'],
    );
  }
}

class WsUnknownEvent extends WsEvent {
  const WsUnknownEvent({
    required String type,
    required this.payload,
  }) : super(type);

  final Map<String, dynamic> payload;
}
