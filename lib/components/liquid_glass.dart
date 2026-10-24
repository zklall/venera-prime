import 'dart:ui' as ui;

import 'package:flutter/material.dart';

@immutable
class LiquidGlassTheme extends ThemeExtension<LiquidGlassTheme> {
  const LiquidGlassTheme({this.enabled = true});

  final bool enabled;

  @override
  LiquidGlassTheme copyWith({bool? enabled}) =>
      LiquidGlassTheme(enabled: enabled ?? this.enabled);

  @override
  LiquidGlassTheme lerp(LiquidGlassTheme? other, double t) =>
      t < .5 ? this : other ?? this;
}

/// A bounded glass surface. Blur is reserved for floating controls; scrolling
/// cards use the same lighting with blur disabled.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding = EdgeInsets.zero,
    this.blur = 14,
    this.shadow = true,
    this.opacity,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final bool shadow;
  final double? opacity;

  static bool enabledOf(BuildContext context) =>
      Theme.of(context).extension<LiquidGlassTheme>()?.enabled == true &&
      !(MediaQuery.maybeOf(context)?.highContrast ?? false);

  static Duration motionDuration(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations == true
      ? Duration.zero
      : const Duration(milliseconds: 220);

  static double overlayOpacityOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? .64 : .54;

  static BoxDecoration selectionDecoration(
    BuildContext context, {
    double selected = 1,
    double radius = 20,
  }) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(
            Colors.white.withValues(alpha: (dark ? .08 : .26) * selected),
            colors.primary.withValues(alpha: .15 * selected),
          ),
          colors.primary.withValues(alpha: .12 * selected),
        ],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: (dark ? .16 : .45) * selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!enabledOf(context)) {
      return Material(
        color: colors.surface,
        borderRadius: borderRadius,
        child: Padding(padding: padding, child: child),
      );
    }
    final dark = colors.brightness == Brightness.dark;
    final tint = opacity ?? (dark ? .36 : .28);
    Widget surface = CustomPaint(
      foregroundPainter: _GlassRimPainter(borderRadius, dark),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                Colors.white.withValues(alpha: dark ? .035 : .08),
                colors.surface.withValues(alpha: tint),
              ),
              colors.surface.withValues(alpha: opacity ?? tint * .6),
              Color.alphaBlend(
                colors.primary.withValues(alpha: dark ? .035 : .025),
                colors.surface.withValues(alpha: opacity ?? tint * .85),
              ),
            ],
            stops: const [0, .55, 1],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (blur > 0) {
      surface = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: surface,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: dark ? .18 : .05),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: surface),
    );
  }
}

class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter(this.radius, this.dark);
  final BorderRadius radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(.7);
    final outline = radius.toRRect(rect);
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? .22 : .60),
            Colors.white.withValues(alpha: dark ? .035 : .10),
            Colors.white.withValues(alpha: dark ? .11 : .38),
          ],
          stops: const [0, .52, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassRimPainter old) =>
      old.radius != radius || old.dark != dark;
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final double radius;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: LiquidGlass.enabledOf(context)
        ? LiquidGlass(
            borderRadius: BorderRadius.circular(radius),
            blur: 0,
            shadow: false,
            child: child,
          )
        : Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: .6,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          ),
  );
}

class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!LiquidGlass.enabledOf(context)) return child;
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-.9, -.8),
            radius: 1.6,
            colors: [
              colors.primary.withValues(alpha: .16),
              colors.primary.withValues(alpha: 0),
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1, .7),
              radius: 1.25,
              colors: [
                colors.tertiary.withValues(alpha: .10),
                colors.tertiary.withValues(alpha: 0),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
