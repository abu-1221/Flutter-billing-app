import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Local, per-install manager access. Not an online identity or a defense against
/// someone who controls the device and can replace the app or read its data.
class ManagerAccess extends ChangeNotifier {
  ManagerAccess(this._box);

  static const boxName = 'manager_access';
  static const _iterations = 120000;
  static const _saltKey = 'salt';
  static const _hashKey = 'hash';
  static const _failuresKey = 'failures';
  static const _retryAtKey = 'retry_at';

  final Box _box;
  bool _unlocked = false;

  bool get isConfigured =>
      _box.get(_hashKey) is String && _box.get(_saltKey) is String;
  bool get isUnlocked => _unlocked;

  int get retrySeconds {
    final until = _box.get(_retryAtKey, defaultValue: 0) as int;
    final remaining = until - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  static bool validPasscode(String value) =>
      value.length >= 10 && value.length <= 128;

  Future<void> configure(String passcode) async {
    if (isConfigured) throw StateError('Manager passcode is already set');
    if (!validPasscode(passcode)) {
      throw ArgumentError('Use at least 10 characters');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final digest = await compute(_derive, _Input(passcode, salt));
    await _box
        .putAll({_saltKey: base64Encode(salt), _hashKey: base64Encode(digest)});
    _unlocked = true;
    notifyListeners();
  }

  Future<bool> unlock(String passcode) async {
    if (!isConfigured || retrySeconds > 0) return false;
    final salt = base64Decode(_box.get(_saltKey) as String);
    final expected = base64Decode(_box.get(_hashKey) as String);
    final actual = await compute(_derive, _Input(passcode, salt));
    var difference = actual.length ^ expected.length;
    for (var i = 0; i < actual.length && i < expected.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    if (difference == 0) {
      await _box.deleteAll([_failuresKey, _retryAtKey]);
      _unlocked = true;
      notifyListeners();
      return true;
    }
    final failures = (_box.get(_failuresKey, defaultValue: 0) as int) + 1;
    await _box.put(_failuresKey, failures);
    if (failures >= 5) {
      // Rate-limit repeated guesses; do not erase the manager credential or billing data.
      await _box.put(
          _retryAtKey,
          DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch);
      await _box.put(_failuresKey, 0);
    }
    return false;
  }

  void lock() {
    _unlocked = false;
    notifyListeners();
  }
}

class _Input {
  const _Input(this.passcode, this.salt);
  final String passcode;
  final List<int> salt;
}

Uint8List _derive(_Input input) {
  // PBKDF2-HMAC-SHA256, one 32-byte block, with a unique random salt.
  final hmac = Hmac(sha256, utf8.encode(input.passcode));
  var previous = hmac.convert([...input.salt, 0, 0, 0, 1]).bytes;
  final result = Uint8List.fromList(previous);
  for (var i = 1; i < ManagerAccess._iterations; i++) {
    previous = hmac.convert(previous).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= previous[j];
    }
  }
  return result;
}
