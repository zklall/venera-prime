import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/pages/reader/reader.dart';
import 'package:venera/utils/reader_spread_alignment.dart';

Future<Uint8List> greyImage(int shade) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 64, 64),
    Paint()..color = Color.fromARGB(255, shade, shade, shade),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets(
    'seam blending has no background gaps and preserves outer pixels on resize',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(500, 400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final images = (await tester.runAsync(
        () => Future.wait([greyImage(80), greyImage(170)]),
      ))!;
      const alignment = ReaderSpreadAlignment(
        scale: 1.014,
        offset: .002,
        confidence: .9,
      );
      const key = ValueKey('spread-paint');
      Widget scene(double width, {bool corrected = true}) => MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: width * 2,
              height: 100,
              child: ColoredBox(
                color: const Color(0xffff00ff),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < 2; i++)
                      Positioned(
                        left: i * width,
                        top: 0,
                        width: width,
                        height: 100,
                        child: ComicImage(
                          image: MemoryImage(images[i]),
                          width: width,
                          height: 100,
                          fit: BoxFit.fill,
                          spreadAlignment: corrected ? alignment : null,
                          spreadAlignmentRightSide: i == 1,
                          spreadBlendWidth: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      Future<List<int>> pixels() async {
        await tester.pump();
        final capture = (await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          final image = await boundary.toImage();
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final bytes = data!.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          final width = image.width;
          image.dispose();
          return (width, bytes);
        }))!;
        final (width, bytes) = capture;
        final row = <int>[];
        for (var x = 0; x < width; x++) {
          final i = (50 * width + x) * 4;
          expect(bytes[i], bytes[i + 1]);
          expect(bytes[i + 1], bytes[i + 2]);
          expect(bytes[i + 3], 255);
          row.add(bytes[i]);
        }
        return row;
      }

      for (final width in [100.0, 150.5]) {
        await tester.pumpWidget(scene(width));
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        final row = await pixels();
        final seam = width.ceil();
        expect(row[10], closeTo(80, 1));
        expect(row.last, closeTo(170, 1));
        expect(row[seam], inExclusiveRange(80, 170));
        expect(row[seam + 1], greaterThan(row[seam]));
        expect(tester.takeException(), isNull);
      }

      await tester.pumpWidget(scene(150, corrected: false));
      final row = await pixels();
      expect(row[149], closeTo(80, 1));
      expect(row[150], closeTo(170, 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
