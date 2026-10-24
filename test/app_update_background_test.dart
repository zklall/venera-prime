import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/background_tasks.dart';
import 'package:venera/pages/settings/settings_page.dart';
import 'package:venera/utils/translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppTranslation.init);
  setUp(() {
    BackgroundTasks.instance.configure(history: {});
    BackgroundTasks.instance.clearFinished();
  });

  test('app update check is shared and keeps a reopenable result', () async {
    final gate = Completer<LatestRelease?>();
    final first = startAppUpdateCheck(fetch: () => gate.future);
    final second = startAppUpdateCheck(
      fetch: () async => throw StateError('duplicate'),
    );
    expect(identical(first, second), isTrue);
    gate.complete(
      const LatestRelease(
        version: '99.0.0',
        title: 'New release',
        body: 'notes',
        url: 'https://example.invalid/release',
      ),
    );
    await first;
    final task = BackgroundTasks.instance.latest('app-update-check')!;
    expect(task.status, BackgroundTaskStatus.completed);
    expect(task.onOpenResult, isNotNull);
    expect(task.message, contains('99.0.0'));
    expect(BackgroundTasks.instance.lastFinished(task.key), isNotNull);
  });

  test('a fork without releases completes without an update', () async {
    expect(await startAppUpdateCheck(fetch: () async => null), isNull);
    final task = BackgroundTasks.instance.latest('app-update-check')!;
    expect(task.status, BackgroundTaskStatus.completed);
    expect(task.onOpenResult, isNull);
    expect(task.message, 'No new version available'.tl);
  });

  test('network and malformed release errors remain failures', () async {
    await expectLater(
      startAppUpdateCheck(fetch: () async => throw StateError('offline')),
      throwsStateError,
    );
    expect(
      BackgroundTasks.instance.latest('app-update-check')!.status,
      BackgroundTaskStatus.failed,
    );
    await expectLater(
      startAppUpdateCheck(fetch: () async => LatestRelease.fromJson({})),
      throwsFormatException,
    );
    final task = BackgroundTasks.instance.latest('app-update-check')!;
    expect(task.status, BackgroundTaskStatus.failed);
    expect(task.onOpenResult, isNull);
  });
}
