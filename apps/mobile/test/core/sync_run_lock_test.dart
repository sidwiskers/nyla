import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/sync/sync_run_lock.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nyla-sync-lock-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('serializes independent sync callers and allows guarded re-entry', () async {
    Future<Directory> directoryProvider() async => directory;
    final first = SyncRunLock(directoryProvider: directoryProvider);
    final second = SyncRunLock(directoryProvider: directoryProvider);
    var active = 0;
    var maximumActive = 0;

    Future<void> run(SyncRunLock lock) => lock.synchronized(() async {
          active += 1;
          if (active > maximumActive) maximumActive = active;

          // Nested guarded SyncService work must not deadlock while an outer
          // background/reset guard already owns the file lock.
          await lock.synchronized(() async {
            await Future<void>.delayed(const Duration(milliseconds: 15));
          });

          active -= 1;
        });

    await Future.wait(<Future<void>>[run(first), run(second)]);
    expect(maximumActive, 1);
  });
}
