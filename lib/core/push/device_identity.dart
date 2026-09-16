import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../storage/session_storage.dart';
import '../utils/app_log.dart';

/// The stable per-device id sent as `device_id` — with the FCM registration
/// (so the server can retire the token of a previous install instead of
/// keeping a ghost registration) and on every GPS point.
///
/// Stable across a reinstall, as `register_device` expects:
/// - **Android**: derived from `ANDROID_ID`, which is scoped to this app's
///   signing key and the device user and survives a reinstall. Only a SHA-256
///   of it ever leaves the device.
/// - **iOS**: a random id kept in the Keychain, which survives a reinstall.
/// - Elsewhere, or when the platform gives nothing: a random id kept in
///   SharedPreferences.
class DeviceIdentity {
  DeviceIdentity({
    required this.prefs,
    FlutterSecureStorage? secureStorage,
    MethodChannel? channel,
  })  : _secure = secureStorage ?? SessionStorage.secureStorage,
        _channel = channel ?? const MethodChannel(_channelName);

  final SharedPreferences prefs;
  final FlutterSecureStorage _secure;
  final MethodChannel _channel;

  static const String _channelName = 'net.digitalharbor.visits/device';
  static const String _prefsKey = StorageKeys.pushDeviceId;
  static const String _keychainKey = StorageKeys.deviceIdentity;

  /// Salt of the hashed platform id, so the value sent is specific to this app.
  static const String _hashSalt = 'net.digitalharbor.visits:';

  /// Hex digits in an id (128 bits).
  static const int _length = 32;
  static const int _hexRadix = 16;

  String? _cached;
  Future<String>? _resolving;

  Future<String> id() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _resolving ??= _resolve().then((value) {
      _cached = value;
      return value;
    }).whenComplete(() => _resolving = null);
  }

  Future<String> _resolve() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final raw = await _channel.invokeMethod<String>('installId');
        if (raw != null && raw.isNotEmpty) return _hash(raw);
      } catch (e) {
        appLog('[DeviceIdentity] install id unavailable: $e');
      }
    }
    if (!kIsWeb && Platform.isIOS) {
      try {
        final stored = await _secure.read(key: _keychainKey);
        if (stored != null && stored.isNotEmpty) return stored;
        // Carry an id this install already registered with over, so the
        // server keeps seeing the same device.
        final id = _fromPrefs() ?? _random();
        await _secure.write(key: _keychainKey, value: id);
        return id;
      } catch (e) {
        appLog('[DeviceIdentity] keychain unavailable: $e');
      }
    }
    final existing = _fromPrefs();
    if (existing != null) return existing;
    final id = _random();
    await prefs.setString(_prefsKey, id);
    return id;
  }

  String? _fromPrefs() {
    try {
      final id = prefs.getString(_prefsKey);
      return id == null || id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  static String _hash(String raw) => sha256
      .convert(utf8.encode('$_hashSalt$raw'))
      .toString()
      .substring(0, _length);

  static String _random() {
    final rand = Random.secure();
    return List.generate(
      _length,
      (_) => rand.nextInt(_hexRadix).toRadixString(_hexRadix),
    ).join();
  }
}
