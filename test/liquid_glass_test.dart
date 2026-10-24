import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/utils/data_sync.dart';
import 'reader_page_margin_test.dart' as reader_fixture;

class _NoDataSync extends Fake implements DataSync {
  @override
  void onDataChanged() {}
  @override
  Future<Res<bool>> uploadData({bool force = false}) async => const Res(true);
}

void main() {
  DataSync? previousSync;
  setUp(() {
    previousSync = DataSync.instance;
    DataSync.instance = _NoDataSync();
  });
  tearDown(() => DataSync.instance = previousSync);
  testWidgets('reader glass is confined to controls and page taps still work', (
    tester,
  ) async {
    final dynamic state = await reader_fixture.openReader(
      tester,
      'galleryLeftToRight',
      theme: ThemeData(extensions: const [LiquidGlassTheme()]),
    );
    await tester.tapAt(const Offset(500, 300));
    await reader_fixture.settle(tester);
    final filters = find.byType(BackdropFilter);
    expect(
      filters,
      ui.ImageFilter.isShaderFilterSupported ? findsNWidgets(2) : findsNothing,
    );
    for (final surface in find.byType(LiquidGlass).evaluate()) {
      final size = tester.getSize(find.byWidget(surface.widget));
      expect(size.height, lessThan(200));
    }
    final before = state.page;
    await tester.tapAt(const Offset(500, 300));
    await reader_fixture.settle(tester);
    await tester.tapAt(const Offset(950, 300));
    await reader_fixture.settle(tester);
    expect(state.page, before + 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await reader_fixture.settle(tester);
  });
  testWidgets('floating navigation respects system insets and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 0;
    final entries = ['Home', 'Favorites', 'Explore', 'Categories'];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [LiquidGlassTheme()]),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24, bottom: 32),
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: NaviPane(
          observer: NaviObserver(),
          navigatorKey: GlobalKey<NavigatorState>(),
          paneItems: [
            for (final title in entries)
              PaneItemEntry(
                label: title,
                icon: Icons.circle_outlined,
                activeIcon: Icons.circle,
              ),
          ],
          paneActions: const [],
          onPageChanged: (index) => selected = index,
          pageBuilder: (_) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final categories = find.text('Categories');
    expect(tester.getRect(categories).bottom, lessThan(800 - 32));
    await tester.tap(categories);
    await tester.pumpAndSettle();
    expect(selected, 3);
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('high contrast keeps controls opaque and usable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [LiquidGlassTheme()]),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: true),
          child: child!,
        ),
        home: Center(
          child: LiquidGlass(
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('Readable control'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(LiquidGlass),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color!.a, 1);
    await tester.tap(find.text('Readable control'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass dialogs retain intrinsic layout and actions', (
    tester,
  ) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [LiquidGlassTheme()]),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => ContentDialog(
                  title: 'Display',
                  content: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Glass surface'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        confirmed = true;
                        Navigator.pop(context);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Glass surface'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
    expect(find.text('Glass surface'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
