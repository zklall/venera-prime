import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/utils/data_sync.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/pages/reader/reader.dart';
import 'reader_page_margin_test.dart' as fixture;

class _NoDataSync extends Fake implements DataSync {
  @override
  void onDataChanged() {}

  @override
  Future<Res<bool>> uploadData({bool force = false}) async => const Res(true);
}

Future<void> closeReader(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
  await fixture.settle(tester);
}

void main() {
  late DataSync? previousSync;
  setUp(() {
    previousSync = DataSync.instance;
    DataSync.instance = _NoDataSync();
  });
  tearDown(() => DataSync.instance = previousSync);

  testWidgets(
    'Komiic spread keeps image 93 left and image 92 right independent of navigation',
    (tester) async {
      // The screenshots show screen 46 = images 91/92, screen 47 = 93/94.
      // The intended pair is 92/93; both are 980x1411 in a 193-image volume.
      final dynamic state = await fixture.openReader(
        tester,
        'galleryLeftToRight',
        imageCount: 193,
        initialPage: 92,
        useDefaultSpreadCover: true,
        useDefaultSpreadPageOrder: true,
        imageSizes: {92: const Size(980, 1411), 93: const Size(980, 1411)},
      );
      appdata.settings['readerTwoPageSpread'] = true;
      state.update();
      await fixture.settle(tester);

      expect(state.imageLayout.range(1), (0, 1));
      expect(state.imageLayout.range(state.page), (91, 93));
      expect(state.maxPage, 97);
      Finder image(int n) => find.byKey(ValueKey('reader-spread-image-$n'));
      final first = tester.getRect(image(92));
      final second = tester.getRect(image(93));
      expect(second.right, closeTo(first.left, 1));
      expect(first.height, closeTo(second.height, 1));

      state.mode = ReaderMode.galleryRightToLeft;
      state.update();
      await fixture.settle(tester);
      expect(state.imageLayout.range(state.page), (91, 93));
      expect(
        tester.getRect(image(93)).right,
        closeTo(tester.getRect(image(92)).left, 1),
      );

      // Page order is a book preference; changing it leaves the current pair
      // and the navigation direction intact.
      final previousOrder = appdata.settings['readerSpreadRightToLeft'];
      addTearDown(() {
        appdata.settings['readerSpreadRightToLeft'] = previousOrder;
      });
      appdata.settings['readerSpreadRightToLeft'] = false;
      state.update();
      await fixture.settle(tester);
      expect(state.mode, ReaderMode.galleryRightToLeft);
      expect(state.imageLayout.range(state.page), (91, 93));
      expect(
        tester.getRect(image(92)).right,
        closeTo(tester.getRect(image(93)).left, 1),
      );
      appdata.settings['readerSpreadRightToLeft'] = previousOrder;
      state.update();
      await fixture.settle(tester);

      appdata.settings['readerTwoPageSpread'] = false;
      state.update();
      await fixture.settle(tester);
      expect(state.page, 92);
      appdata.settings['readerTwoPageSpread'] = true;
      state.update();
      await fixture.settle(tester);
      expect(state.imageLayout.range(state.page), (91, 93));
      expect(
        tester.getRect(image(93)).right,
        closeTo(tester.getRect(image(92)).left, 1),
      );
      expect(appdata.settings['showSingleImageOnFirstPage'], isFalse);
      expect(tester.takeException(), isNull);
      await closeReader(tester);
    },
  );

  testWidgets(
    'book spreads align uneven pages, isolate wide images and retain progress',
    (tester) async {
      final dynamic state = await fixture.openReader(
        tester,
        'galleryLeftToRight',
        imageSizes: {
          9: const Size(300, 600),
          10: const Size(510, 600),
          11: const Size(1200, 600),
        },
      );
      appdata.settings['readerTwoPageSpread'] = true;
      state.update();
      await fixture.settle(tester);
      Finder image(int n) => find.byKey(ValueKey('reader-spread-image-$n'));
      final left = tester.getRect(image(9));
      final right = tester.getRect(image(10));
      expect(left.height, closeTo(right.height, 1));
      expect(left.top, closeTo(right.top, 1));
      expect(left.right, closeTo(right.left, 1));
      expect(left.width / left.height, closeTo(.5, .01));
      expect(right.width / right.height, closeTo(.85, .01));

      state.toPage(state.imageLayout.pageForImage(11), animate: false);
      await fixture.settle(tester);
      expect(state.imageLayout.range(state.page), (10, 11));
      expect(tester.getSize(image(11)).width, greaterThan(right.width));
      tester.view.physicalSize = const Size(600, 1000);
      await fixture.settle(tester);
      expect(state.imageLayout.range(state.page), (10, 11));
      appdata.settings['readerTwoPageSpread'] = false;
      state.update();
      await fixture.settle(tester);
      expect(state.page, 11);
      expect(tester.takeException(), isNull);
      await closeReader(tester);
    },
  );

  testWidgets('manual cross-page marking persists and can be reset', (
    tester,
  ) async {
    dynamic state = await fixture.openReader(tester, 'galleryLeftToRight');
    appdata.settings['readerTwoPageSpread'] = true;
    state.update();
    await fixture.settle(tester);
    state.setSpreadOverride('pair');
    await fixture.settle(tester);
    final saved = appdata.settings['readerSpreadOverrides'] as Map;
    expect(saved.values.single, {'8': 'pair'});
    final root = tester.widget<MaterialApp>(find.byType(MaterialApp));
    await closeReader(tester);
    await tester.pumpWidget(root);
    await fixture.settle(tester);
    state = tester.state(find.byType(Reader));
    expect(state.joinedSpreadPairs, {8});
    state.shiftImage(1);
    await fixture.settle(tester);
    expect(state.imageLayout.range(state.page), (8, 10));
    state.setSpreadOverride(null);
    await fixture.settle(tester);
    expect(appdata.settings['readerSpreadOverrides'], isEmpty);
    expect(tester.takeException(), isNull);
    await closeReader(tester);
  });

  testWidgets('reset removes a forced-page override inside a regrouped pair', (
    tester,
  ) async {
    final dynamic state = await fixture.openReader(
      tester,
      'galleryLeftToRight',
      imageSizes: {10: const Size(1200, 600)},
    );
    appdata.settings['readerTwoPageSpread'] = true;
    state.update();
    await fixture.settle(tester);
    state.toPage(state.imageLayout.pageForImage(10), animate: false);
    await fixture.settle(tester);
    expect(state.imageLayout.range(state.page), (9, 10));
    state.setSpreadOverride('page');
    await fixture.settle(tester);
    expect(state.imageLayout.range(state.page), (8, 10));
    state.setSpreadOverride(null);
    await fixture.settle(tester);
    expect(state.imageLayout.range(state.imageLayout.pageForImage(10)), (
      9,
      10,
    ));
    expect(appdata.settings['readerSpreadOverrides'], isEmpty);
    expect(tester.takeException(), isNull);
    await closeReader(tester);
  });

  testWidgets(
    'double tap focuses the selected page and returns to the spread',
    (tester) async {
      final dynamic state = await fixture.openReader(
        tester,
        'galleryRightToLeft',
      );
      appdata.settings['readerTwoPageSpread'] = true;
      state.update();
      await fixture.settle(tester);
      final gallery = tester.widget<PhotoViewGallery>(
        find.byType(PhotoViewGallery),
      );
      final options = gallery.builder!(
        tester.element(find.byType(PhotoViewGallery)),
        state.page as int,
      );
      final controller = options.controller!;
      final initial = controller.getInitialScale!.call()!;
      final target = tester
          .getRect(find.byKey(const ValueKey('reader-spread-image-9')))
          .center;
      await tester.tapAt(target);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(target);
      await fixture.settle(tester);
      expect(controller.scale, greaterThan(initial * 1.2));
      await tester.tapAt(target);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(target);
      await fixture.settle(tester);
      expect(controller.scale, closeTo(initial, .01));
      expect(tester.takeException(), isNull);
      await closeReader(tester);
    },
  );
}
