import 'dart:io';

import 'package:billing_app/core/data/manager_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('manager-access-test');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('no default passcode, setup and local unlock', () async {
    final box = await Hive.openBox(ManagerAccess.boxName);
    final access = ManagerAccess(box);
    expect(access.isConfigured, false);
    expect(access.isUnlocked, false);
    expect(await access.unlock('admin'), false);
    expect(() => access.configure('too-short'), throwsArgumentError);
    await access.configure('long passcode chosen by owner');
    expect(
        box.values.join(' '), isNot(contains('long passcode chosen by owner')));
    access.lock();
    expect(await access.unlock('admin'), false);
    expect(access.isUnlocked, false);
    expect(await access.unlock('long passcode chosen by owner'), true);
    expect(access.isUnlocked, true);
    expect(() => access.configure('a second passcode'), throwsStateError);
  });

  test('credential survives restart, access does not', () async {
    var box = await Hive.openBox(ManagerAccess.boxName);
    final first = ManagerAccess(box);
    await first.configure('long passcode chosen by owner');
    await box.close();
    box = await Hive.openBox(ManagerAccess.boxName);
    final restarted = ManagerAccess(box);
    expect(restarted.isConfigured, true);
    expect(restarted.isUnlocked, false);
    expect(await restarted.unlock('long passcode chosen by owner'), true);
  });

  test('repeated guesses lock attempts for five minutes', () async {
    final box = await Hive.openBox(ManagerAccess.boxName);
    final access = ManagerAccess(box);
    await access.configure('long passcode chosen by owner');
    access.lock();
    for (var i = 0; i < 5; i++) {
      expect(await access.unlock('not correct'), false);
    }
    expect(access.retrySeconds, greaterThan(0));
    expect(await access.unlock('long passcode chosen by owner'), false);
  });
}
