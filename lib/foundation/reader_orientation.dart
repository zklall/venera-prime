import 'dart:ui' show DisplayFeature;

import 'package:flutter/widgets.dart';

import 'appdata.dart';

/// Rotation relative to the screen, independent of Android's classification of
/// a foldable's inner display as portrait or landscape.
enum ReaderRotation {
  normal(0, 'Default direction'),
  left(3, 'Rotate left 90°'),
  right(1, 'Rotate right 90°');

  const ReaderRotation(this.quarterTurns, this.label);
  final int quarterTurns;
  final String label;

  static ReaderRotation? fromStorage(Object? value) {
    for (final rotation in values) {
      if (rotation.name == value) return rotation;
    }
    return null;
  }

  Size rotateSize(Size size) =>
      quarterTurns.isOdd ? Size(size.height, size.width) : size;

  EdgeInsets rotateInsets(EdgeInsets insets) => switch (quarterTurns) {
    1 => EdgeInsets.fromLTRB(
      insets.top,
      insets.right,
      insets.bottom,
      insets.left,
    ),
    3 => EdgeInsets.fromLTRB(
      insets.bottom,
      insets.left,
      insets.top,
      insets.right,
    ),
    _ => insets,
  };

  Rect _rotateRect(Rect rect, Size screen) => switch (quarterTurns) {
    1 => Rect.fromLTRB(
      rect.top,
      screen.width - rect.right,
      rect.bottom,
      screen.width - rect.left,
    ),
    3 => Rect.fromLTRB(
      screen.height - rect.bottom,
      rect.left,
      screen.height - rect.top,
      rect.right,
    ),
    _ => rect,
  };

  MediaQueryData mediaQuery(MediaQueryData data, Size viewport) =>
      data.copyWith(
        size: rotateSize(viewport),
        padding: rotateInsets(data.padding),
        viewPadding: rotateInsets(data.viewPadding),
        viewInsets: rotateInsets(data.viewInsets),
        systemGestureInsets: rotateInsets(data.systemGestureInsets),
        displayFeatures: [
          for (final feature in data.displayFeatures)
            DisplayFeature(
              bounds: _rotateRect(feature.bounds, viewport),
              type: feature.type,
              state: feature.state,
            ),
        ],
      );
}

class ReaderRotationPreference {
  static const settingKey = 'readerRotationDefault';

  static ReaderRotation? get pinned =>
      ReaderRotation.fromStorage(appdata.settings[settingKey]);

  static ReaderRotation get initial => pinned ?? ReaderRotation.normal;

  static Future<void> pin(ReaderRotation? rotation) {
    appdata.settings[settingKey] = rotation?.name ?? 'none';
    return appdata.saveData();
  }
}
