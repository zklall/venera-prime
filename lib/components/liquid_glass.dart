import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

/// Clear glass: the centre is untouched and a narrow bevel refracts the
/// backdrop. Renderers without shader filters keep a clear, unblurred surface.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding = EdgeInsets.zero,
    this.refract = true,
    this.shadow = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final bool refract;
  final bool shadow;

  static Future<ui.FragmentProgram>? _program;

  static Future<ui.FragmentProgram> loadProgram() =>
      _program ??= ui.FragmentProgram.fromAsset('shaders/clear_glass.frag');

  static bool enabledOf(BuildContext context) =>
      Theme.of(context).extension<LiquidGlassTheme>()?.enabled == true &&
      !(MediaQuery.maybeOf(context)?.highContrast ?? false);

  static Duration motionDuration(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations == true
      ? Duration.zero
      : const Duration(milliseconds: 220);

  static BoxDecoration selectionDecoration(
    BuildContext context, {
    double selected = 1,
    double radius = 20,
  }) {
    final colors = Theme.of(context).colorScheme;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: .04 * selected),
          colors.primary.withValues(alpha: .055 * selected),
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: .30 * selected)),
    );
  }

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  ui.FragmentShader? _shader;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadShader();
  }

  @override
  void didUpdateWidget(LiquidGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadShader();
  }

  void _loadShader() {
    if (_loading ||
        _shader != null ||
        !widget.refract ||
        !LiquidGlass.enabledOf(context) ||
        !ui.ImageFilter.isShaderFilterSupported) {
      return;
    }
    _loading = true;
    LiquidGlass.loadProgram()
        .then((program) {
          if (mounted) setState(() => _shader = program.fragmentShader());
        })
        .catchError((Object error) {
          debugPrint('Clear glass shader: $error');
        })
        .whenComplete(() => _loading = false);
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!LiquidGlass.enabledOf(context)) {
      return Material(
        color: colors.surface,
        borderRadius: widget.borderRadius,
        child: Padding(padding: widget.padding, child: widget.child),
      );
    }
    final inkShadows = widget.refract
        ? [
            for (final offset in const [
              Offset(-.7, 0),
              Offset(.7, 0),
              Offset(0, -.7),
              Offset(0, .7),
            ])
              Shadow(
                color: colors.surface.withValues(alpha: .95),
                offset: offset,
                blurRadius: .6,
              ),
          ]
        : const <Shadow>[];
    Widget surface = Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: TextStyle(shadows: inkShadows),
        child: IconTheme.merge(
          data: IconThemeData(shadows: inkShadows),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
    if (_shader != null && widget.refract) {
      surface = BackdropFilter(
        filterConfig: _GlassRefractionFilter(
          _shader!,
          widget.borderRadius,
          MediaQuery.devicePixelRatioOf(context),
          () {
            final box = context.findRenderObject()! as RenderBox;
            return Rect.fromPoints(
              box.localToGlobal(Offset.zero),
              box.localToGlobal(Offset(box.size.width, box.size.height)),
            );
          },
        ),
        child: surface,
      );
    }
    return CustomPaint(
      painter: widget.shadow ? _GlassCastShadow(widget.borderRadius) : null,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: CustomPaint(
          foregroundPainter: _GlassRimPainter(widget.borderRadius),
          child: surface,
        ),
      ),
    );
  }
}

@immutable
class _GlassRefractionFilter implements ImageFilterConfig {
  const _GlassRefractionFilter(
    this.shader,
    this.radius,
    this.pixelRatio,
    this.globalBounds,
  );
  final ui.FragmentShader shader;
  final BorderRadius radius;
  final double pixelRatio;
  final Rect Function() globalBounds;

  @override
  ui.ImageFilter resolve(ImageFilterContext context) {
    final bounds = globalBounds();
    final scale = bounds.width / context.bounds.width;
    shader
      ..setFloat(2, bounds.width)
      ..setFloat(3, bounds.height)
      ..setFloat(4, bounds.left)
      ..setFloat(5, bounds.top)
      ..setFloat(6, radius.topLeft.x * scale)
      ..setFloat(7, radius.topRight.x * scale)
      ..setFloat(8, radius.bottomRight.x * scale)
      ..setFloat(9, radius.bottomLeft.x * scale)
      ..setFloat(10, 14 * scale)
      ..setFloat(11, 5 * scale)
      ..setFloat(12, pixelRatio);
    return ui.ImageFilter.shader(shader);
  }

  @override
  ui.ImageFilter? get filter => null;
  @override
  String get debugShortDescription => 'clearGlassRefraction';
}

class _GlassCastShadow extends CustomPainter {
  const _GlassCastShadow(this.radius);
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shape = radius.toRRect(Offset.zero & size);
    // A filled box shadow would darken the transparent centre as well.
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(32))
        ..addRRect(shape),
    );
    canvas.drawRRect(
      shape.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: .14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassCastShadow old) => old.radius != radius;
}

class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter(this.radius);
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(.65);
    canvas.drawRRect(
      radius.toRRect(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCFFFFFFF), Color(0x10FFFFFF), Color(0x65FFFFFF)],
          stops: [0, .48, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassRimPainter old) => old.radius != radius;
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
            refract: false,
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
