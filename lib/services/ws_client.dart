import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import '../models/ws_models.dart';
import 'auth_storage.dart';

/// Factory signature for creating a [WebSocketChannel], injectable for tests.
typedef WsChannelFactory = WebSocketChannel Function(
  Uri uri,
  Map<String, dynamic> headers,
);

/// Authenticated WebSocket client for HealthWing `ws_server.php`.
///
/// Authenticates with `ws_token` and streams live triage, chat, typing, and
/// WebRTC signaling frames.
class WsClient {
  WsClient({
    this._config,
    AuthStorage? authStorage,
    WsChannelFactory? channelFactory,
  })  : _authStorage = authStorage ?? AuthStorage(),
        _channelFactory = channelFactory ?? _defaultChannelFactory;

  static WebSocketChannel _defaultChannelFactory(
    Uri uri,
    Map<String, dynamic> headers,
  ) {
    return IOWebSocketChannel.connect(uri, headers: headers);
  }

  final ApiConfig? _config;
  final AuthStorage _authStorage;
  final WsChannelFactory _channelFactory;

  ApiConfig get config => _config ?? ApiConfig.current;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  String? _activeToken;
  bool _authSent = false;
  bool _disposed = false;

  final Set<String> _subscribedChannels = <String>{};
  WsConnectionState _state = WsConnectionState.disconnected;

  final StreamController<WsConnectionState> _stateController =
      StreamController<WsConnectionState>.broadcast();
  final StreamController<WsEvent> _eventController =
      StreamController<WsEvent>.broadcast();

  /// Current connection and authentication state.
  WsConnectionState get state => _state;

  /// True when the server has confirmed `auth_ok` on the active socket.
  bool get isAuthenticated => _state == WsConnectionState.authenticated;

  /// Broadcast stream of connection/authentication state transitions.
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  /// Broadcast stream of all typed WebSocket events.
  Stream<WsEvent> get events => _eventController.stream;

  /// Filtered stream of incoming live chat messages.
  Stream<WsChatMessageEvent> get chatMessages => events
      .where((event) => event is WsChatMessageEvent)
      .cast<WsChatMessageEvent>();

  /// Filtered stream of live triage queue broadcasts.
  Stream<WsTriageBroadcastEvent> get triageBroadcasts => events
      .where((event) => event is WsTriageBroadcastEvent)
      .cast<WsTriageBroadcastEvent>();

  /// Filtered stream of live typing indicators.
  Stream<WsTypingEvent> get typingEvents =>
      events.where((event) => event is WsTypingEvent).cast<WsTypingEvent>();

  /// Filtered stream of WebRTC call signaling packets.
  Stream<WsWebRtcSignalEvent> get webrtcSignals => events
      .where((event) => event is WsWebRtcSignalEvent)
      .cast<WsWebRtcSignalEvent>();

  /// Opens the WebSocket connection and authenticates using [wsToken] (or the
  /// stored `ws_token` from [AuthStorage]).
  Future<void> connect({
    String? wsToken,
    List<String> initialChannels = const <String>[],
  }) async {
    _ensureNotDisposed();

    final resolvedToken = (wsToken?.trim().isNotEmpty ?? false)
        ? wsToken!.trim()
        : await _authStorage.readWsToken();
    if (resolvedToken == null || resolvedToken.isEmpty) {
      _setState(WsConnectionState.error);
      throw StateError('Missing ws_token for WebSocket authentication.');
    }

    await disconnect();

    _activeToken = resolvedToken;
    _authSent = false;
    for (final ch in initialChannels) {
      final trimmed = ch.trim();
      if (trimmed.isNotEmpty) {
        _subscribedChannels.add(trimmed);
      }
    }

    _setState(WsConnectionState.connecting);

    final headers = <String, dynamic>{
      'Origin': config.resolveWsOrigin(),
    };

    try {
      final channel = _channelFactory(config.wsUri, headers);
      _channel = channel;

      _subscription = channel.stream.listen(
        _handleIncomingFrame,
        onError: (Object error, StackTrace stackTrace) {
          _setState(WsConnectionState.error);
          if (!_eventController.isClosed) {
            _eventController.addError(error, stackTrace);
          }
        },
        onDone: () {
          _authSent = false;
          if (_state != WsConnectionState.error) {
            _setState(WsConnectionState.disconnected);
          }
        },
        cancelOnError: false,
      );

      await channel.ready;
      _sendAuthIfNeeded();
    } catch (e) {
      _setState(WsConnectionState.error);
      rethrow;
    }
  }

  /// Subscribes to a channel such as `booking_<id>` or `schedule_<id>`.
  void subscribe(String channelKey) {
    final trimmed = channelKey.trim();
    if (trimmed.isEmpty) return;
    _subscribedChannels.add(trimmed);
    if (isAuthenticated) {
      _sendRaw({
        'type': 'subscribe',
        'channel_key': trimmed,
      });
    }
  }

  /// Sends a live chat message on [channelKey].
  ///
  /// Allowed [messageType] values: `text`, `system_alert`, `triage_notice`,
  /// `call_event`.
  void sendChatMessage({
    required String channelKey,
    required String messageText,
    String messageType = 'text',
  }) {
    final trimmedChannel = channelKey.trim();
    final trimmedText = messageText.trim();
    if (trimmedChannel.isEmpty || trimmedText.isEmpty) return;

    _sendAuthenticated({
      'type': 'chat_message',
      'channel_key': trimmedChannel,
      'message_text': trimmedText,
      'message_type': messageType,
    });
  }

  /// Sends a typing indicator on [channelKey].
  void sendTyping(String channelKey) {
    final trimmed = channelKey.trim();
    if (trimmed.isEmpty) return;

    _sendAuthenticated({
      'type': 'typing',
      'channel_key': trimmed,
    });
  }

  /// Sends a WebRTC signaling message for an emergency [bookingId].
  ///
  /// Allowed [signalType] values: `offer`, `answer`, `ice`, `hangup`,
  /// `decline`, `busy`. Allowed [callType] values: `video`, `audio`.
  void sendWebRtcSignal({
    required int bookingId,
    required String signalType,
    Object? callId,
    String callType = 'video',
    Object? payload,
  }) {
    if (bookingId <= 0) return;

    _sendAuthenticated({
      'type': 'webrtc_signal',
      'booking_id': bookingId,
      'signal_type': signalType,
      'call_id': ?callId,
      'call_type': callType,
      'payload': ?payload,
    });
  }

  /// Sends a triage queue broadcast (authorized for `vet_staff` and `head_vet`).
  void sendTriageBroadcast({Object? summary}) {
    _sendAuthenticated({
      'type': 'triage_broadcast',
      'summary': ?summary,
    });
  }

  /// Closes the active WebSocket connection without disposing event streams.
  Future<void> disconnect() async {
    _authSent = false;
    _subscribedChannels.clear();
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.sink.close();
      } catch (_) {
        // Ignore transport close errors during teardown.
      }
    }
    if (!_disposed && _state != WsConnectionState.disconnected) {
      _setState(WsConnectionState.disconnected);
    }
  }

  /// Closes the WebSocket and disposes all stream controllers.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await _eventController.close();
    await _stateController.close();
  }

  void _handleIncomingFrame(dynamic rawFrame) {
    if (rawFrame is! String || rawFrame.trim().isEmpty) {
      return;
    }
    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(rawFrame);
      if (parsed is! Map) return;
      decoded = parsed.map((key, val) => MapEntry(key.toString(), val));
    } on FormatException {
      return;
    }

    final event = WsEvent.fromJson(decoded);
    switch (event) {
      case WsConnectedEvent():
        _sendAuthIfNeeded();
      case WsAuthOkEvent():
        _setState(WsConnectionState.authenticated);
        for (final ch in _subscribedChannels) {
          _sendRaw({
            'type': 'subscribe',
            'channel_key': ch,
          });
        }
      case WsAuthErrorEvent():
        _setState(WsConnectionState.error);
      case WsChatMessageEvent():
      case WsTypingEvent():
      case WsWebRtcSignalEvent():
      case WsTriageBroadcastEvent():
      case WsUnknownEvent():
        break;
    }

    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _sendAuthIfNeeded() {
    if (_authSent || _channel == null) return;
    final token = _activeToken;
    if (token == null || token.isEmpty) return;

    _authSent = true;
    _setState(WsConnectionState.authenticating);
    _sendRaw({
      'type': 'auth',
      'token': token,
    });
  }

  void _sendAuthenticated(Map<String, dynamic> payload) {
    if (!isAuthenticated || _channel == null) {
      throw StateError('WebSocket is not authenticated.');
    }
    _sendRaw(payload);
  }

  void _sendRaw(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(payload));
  }

  void _setState(WsConnectionState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('WsClient has already been disposed.');
    }
  }
}
