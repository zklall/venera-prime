import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/reader_orientation_behavior.dart';

void main() {
  group('ReaderOrientationBehavior', () {
    test('migrates every legacy switch combination', () {
      expect(
        ReaderOrientationBehavior.fromLegacySettings(
          rememberOrientation: false,
          rememberPerComic: false,
        ),
        ReaderOrientationBehavior.keepAfterExit,
      );
      expect(
        ReaderOrientationBehavior.fromLegacySettings(
          rememberOrientation: false,
          rememberPerComic: true,
        ),
        ReaderOrientationBehavior.keepAfterExit,
      );
      expect(
        ReaderOrientationBehavior.fromLegacySettings(
          rememberOrientation: true,
          rememberPerComic: false,
        ),
        ReaderOrientationBehavior.rememberGlobally,
      );
      expect(
        ReaderOrientationBehavior.fromLegacySettings(
          rememberOrientation: true,
          rememberPerComic: true,
        ),
        ReaderOrientationBehavior.rememberPerComic,
      );
    });

    test('unknown stored behavior safely keeps the legacy exit behavior', () {
      expect(
        ReaderOrientationBehavior.fromStorage('not-a-real-behavior'),
        ReaderOrientationBehavior.keepAfterExit,
      );
    });

    test('only the legacy mode keeps rotation after exit', () {
      expect(ReaderOrientationBehavior.keepAfterExit.restoresOnExit, isFalse);
      expect(ReaderOrientationBehavior.sessionOnly.restoresOnExit, isTrue);
      expect(ReaderOrientationBehavior.rememberGlobally.restoresOnExit, isTrue);
      expect(ReaderOrientationBehavior.rememberPerComic.restoresOnExit, isTrue);
    });

    test('session mode restores without remembering', () {
      expect(
        ReaderOrientationBehavior.sessionOnly.remembersOrientation,
        isFalse,
      );
      expect(
        ReaderOrientationBehavior.rememberGlobally.remembersOrientation,
        isTrue,
      );
      expect(
        ReaderOrientationBehavior.rememberPerComic.remembersPerComic,
        isTrue,
      );
    });
  });
}
