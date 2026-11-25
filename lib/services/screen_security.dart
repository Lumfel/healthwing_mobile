import 'package:flutter/services.dart';

/// Dart wrapper for the Android `healthwing/security` anti-screenshot channel.
///
/// Controls `WindowManager.LayoutParams.FLAG_SECURE` to protect sensitive
/// clinical records, prescriptions, and receipt data under RA 10173.
class ScreenSecurity {
  ScreenSecurity({MethodChannel? channel})
      : _channel = channel ?? defaultChannel;

  static const String channelName = 'healthwing/security';
  static const String setSecureScreenMethod = 'setSecureScreen';
  static const MethodChannel defaultChannel = MethodChannel(channelName);

  final MethodChannel _channel;
  bool _isSecure = false;

  /// Last successfully applied secure-screen state.
  bool get isSecure => _isSecure;

  /// Toggles Android `FLAG_SECURE` via `MethodChannel("healthwing/security")`.
  ///
  /// Returns the resulting flag state, or `false` on platforms where the native
  /// channel is not registered.
  Future<bool> setSecureScreen(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        setSecureScreenMethod,
        <String, dynamic>{'enabled': enabled},
      );
      _isSecure = result ?? enabled;
      return _isSecure;
    } on MissingPluginException {
      return false;
    }
  }

  /// Enables screenshot and screen-recording protection (`FLAG_SECURE`).
  Future<bool> enable() => setSecureScreen(true);

  /// Disables screenshot and screen-recording protection (`FLAG_SECURE`).
  Future<bool> disable() => setSecureScreen(false);

  /// Runs [action] with `FLAG_SECURE` enabled and restores the previous state
  /// when [action] completes or throws.
  Future<T> runProtected<T>(Future<T> Function() action) async {
    final previous = _isSecure;
    await setSecureScreen(true);
    try {
      return await action();
    } finally {
      await setSecureScreen(previous);
    }
  }
}
