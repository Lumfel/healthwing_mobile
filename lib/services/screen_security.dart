import 'package:flutter/services.dart';

/// Dart wrapper for the Android `healthwing/security` anti-screenshot channel.
///
/// Uses a reference counter (`_secureDepth`) to control
/// `WindowManager.LayoutParams.FLAG_SECURE` so stacked protected screens do not
/// clear screenshot protection early under RA 10173.
class ScreenSecurity {
  ScreenSecurity({MethodChannel? channel})
      : _channel = channel ?? defaultChannel;

  static const String channelName = 'healthwing/security';
  static const String setSecureScreenMethod = 'setSecureScreen';
  static const MethodChannel defaultChannel = MethodChannel(channelName);

  final MethodChannel _channel;
  int _secureDepth = 0;

  /// Active reference count of screens holding `FLAG_SECURE`.
  int get secureDepth => _secureDepth;

  /// True while at least one protected screen holds `FLAG_SECURE`.
  bool get isSecure => _secureDepth > 0;

  /// Toggles Android `FLAG_SECURE` via `MethodChannel("healthwing/security")`.
  ///
  /// Increments `_secureDepth` when [enabled] is true and only clears
  /// `FLAG_SECURE` when `_secureDepth` returns to `0`. Returns the active
  /// secure-screen state, or `false` on platforms where the native channel is
  /// not registered.
  Future<bool> setSecureScreen(bool enabled) async {
    if (enabled) {
      _secureDepth++;
      if (_secureDepth > 1) {
        return true;
      }
      try {
        final result = await _channel.invokeMethod<bool>(
          setSecureScreenMethod,
          <String, dynamic>{'enabled': true},
        );
        final applied = result ?? true;
        if (!applied) {
          _secureDepth = 0;
        }
        return applied;
      } on MissingPluginException {
        _secureDepth = 0;
        return false;
      }
    }

    if (_secureDepth > 0) {
      _secureDepth--;
    }
    if (_secureDepth > 0) {
      return true;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        setSecureScreenMethod,
        <String, dynamic>{'enabled': false},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Enables screenshot and screen-recording protection (`FLAG_SECURE`).
  Future<bool> enable() => setSecureScreen(true);

  /// Disables screenshot and screen-recording protection (`FLAG_SECURE`).
  Future<bool> disable() => setSecureScreen(false);

  /// Runs [action] with `FLAG_SECURE` enabled and decrements the reference
  /// count cleanly when [action] completes or throws.
  Future<T> runProtected<T>(Future<T> Function() action) async {
    await setSecureScreen(true);
    try {
      return await action();
    } finally {
      await setSecureScreen(false);
    }
  }
}
