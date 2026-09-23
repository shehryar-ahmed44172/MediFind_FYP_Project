import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

/// Stores the MediFind server address a tester types in the app.
///
/// Test builds point at a laptop on Wi-Fi or at a tunnel, and that address
/// changes. Keeping it here means a new address needs a few taps instead of a
/// new APK. The value is per-device and never leaves the phone.
class ServerConfig {
  static const _key = 'server_api_host';

  /// Applies the saved address (if any) before anything builds a URL.
  /// Safe to call more than once.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key) ?? '';
      if (saved.isNotEmpty) AppConstants.setRuntimeApiHost(saved);
    } catch (e) {
      debugPrint('[ServerConfig] could not read the saved address: $e');
    }
  }

  /// Saves [host] and applies it immediately. Empty clears it.
  static Future<void> save(String? host) async {
    final normalised = normalise(host);
    AppConstants.setRuntimeApiHost(normalised);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (normalised.isEmpty) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, normalised);
      }
    } catch (e) {
      debugPrint('[ServerConfig] could not save the address: $e');
    }
  }

  /// Accepts what people actually paste: a bare host, a full URL, a trailing
  /// slash or an `/api` suffix. Returns '' when nothing usable is left.
  static String normalise(String? input) {
    var value = (input ?? '').trim();
    if (value.isEmpty) return '';
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      // Anything that is not a plain LAN address is assumed to be https.
      final looksLocal = RegExp(r'^(localhost|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)')
          .hasMatch(value);
      value = '${looksLocal ? 'http' : 'https'}://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return '';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  /// True when the address looks like something we can talk to.
  static bool isValid(String? input) => normalise(input).isNotEmpty;
}
