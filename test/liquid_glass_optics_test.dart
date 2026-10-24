import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/liquid_glass.dart';

class _SharpBackdrop extends CustomPainter {
  const _SharpBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    for (var y = 0; y < size.height; y += 4) {
      for (var x = 0; x < size.width; x += 4) {
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 4, 4),
          Paint()
            ..color = (x ~/ 4 + y ~/ 4).isEven
                ? const Color(0xff204768)
                : const Color(0xffe4d2b8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SharpBackdrop old) => false;
}

void main() {
  testWidgets(
    'clear centre preserves backdrop detail; only bevel refracts after move and resize',
    (tester) async {
      await tester.runAsync(LiquidGlass.loadProgram);
      const key = ValueKey('optics');
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<Uint8List> capture(
        Rect lens,
        double ratio,
        bool enabled,
        bool nested,
        int turns,
      ) async {
        tester.view.devicePixelRatio = ratio;
        tester.view.physicalSize = Size(400 * ratio, 280 * ratio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: const [LiquidGlassTheme()]),
            home: RepaintBoundary(
              key: key,
              child: Padding(
                padding: nested
                    ? const EdgeInsets.only(left: 32, top: 24)
                    : EdgeInsets.zero,
                child: RepaintBoundary(
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: _SharpBackdrop()),
                      ),
                      if (enabled)
                        Positioned.fromRect(
                          rect: lens,
                          child: RotatedBox(
                            quarterTurns: turns,
                            child: const LiquidGlass(
                              borderRadius: BorderRadius.all(
                                Radius.circular(28),
                              ),
                              child: SizedBox.expand(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        if (enabled) expect(find.byType(BackdropFilter), findsOneWidget);
        return (await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          final image = await boundary.toImage(pixelRatio: ratio);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final bytes = Uint8List.fromList(
            data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          image.dispose();
          return bytes;
        }))!;
      }

      for (final sample in [
        (const Rect.fromLTWH(68, 84, 220, 100), 1.0, false, 0),
        (const Rect.fromLTWH(96, 40, 180, 160), 2.0, false, 0),
        (const Rect.fromLTWH(68, 44, 220, 130), 2.0, true, 0),
        (const Rect.fromLTWH(68, 44, 220, 130), 2.0, true, 1),
        (const Rect.fromLTWH(68, 44, 220, 130), 2.0, true, 3),
      ]) {
        final (localLens, ratio, nested, turns) = sample;
        final lens = localLens.shift(
          nested ? const Offset(32, 24) : Offset.zero,
        );
        final before = await capture(localLens, ratio, false, nested, turns);
        final after = await capture(localLens, ratio, true, nested, turns);
        final width = (400 * ratio).round();
        double difference(Rect area) {
          var sum = 0, count = 0;
          for (
            var y = (area.top * ratio).ceil();
            y < area.bottom * ratio;
            y++
          ) {
            for (
              var x = (area.left * ratio).ceil();
              x < area.right * ratio;
              x++
            ) {
              final i = (y * width + x) * 4;
              for (var channel = 0; channel < 3; channel++) {
                sum += (before[i + channel] - after[i + channel]).abs();
                count++;
              }
            }
          }
          return sum / count;
        }

        final centre = difference(lens.deflate(24));
        final bevel = difference(
          Rect.fromLTWH(lens.left + 4, lens.top + 30, 7, lens.height - 60),
        );
        final outside = difference(const Rect.fromLTWH(8, 8, 20, 20));
        debugPrint(
          'clear glass DPR $ratio turns $turns: centre=$centre, bevel=$bevel, outside=$outside',
        );
        expect(
          centre,
          lessThan(1.5),
          reason: 'centre must not be blurred or tinted',
        );
        expect(
          bevel,
          greaterThan(5),
          reason: 'inner bevel must actually bend the backdrop',
        );
        expect(outside, lessThan(.1));
        expect(tester.takeException(), isNull);
      }
    },
    skip: !ui.ImageFilter.isShaderFilterSupported,
  );
}
