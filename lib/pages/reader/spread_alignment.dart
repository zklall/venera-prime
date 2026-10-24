part of 'reader.dart';

class _ReaderSpreadInnerClipper extends CustomClipper<Rect> {
  const _ReaderSpreadInnerClipper(this.width);
  final double width;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(width, 0, size.width - width, size.height);
  @override
  bool shouldReclip(_ReaderSpreadInnerClipper old) => old.width != width;
}

Future<List<double>?> _readerEdgeProfile(
  ui.Image image, {
  required bool right,
}) async {
  final width = math.min(12, image.width);
  final height = math.min(512, image.height);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(
      right ? (image.width - width).toDouble() : 0,
      0,
      width.toDouble(),
      image.height.toDouble(),
    ),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  ui.Image? strip;
  try {
    strip = await picture.toImage(width, height);
    final data = await strip.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return List<double>.generate(height, (row) {
      var sum = 0.0;
      for (var col = 0; col < width; col++) {
        final i = (row * width + col) * 4;
        sum +=
            .2126 * bytes[i] +
            .7152 * bytes[i + 1] +
            .0722 * bytes[i + 2] +
            255 -
            bytes[i + 3];
      }
      return sum / width;
    });
  } finally {
    strip?.dispose();
    picture.dispose();
  }
}

class _ReaderSpreadWarpPainter extends CustomPainter {
  _ReaderSpreadWarpPainter({
    required this.image,
    required this.alignment,
    required this.filterQuality,
    required this.invertColors,
    required this.rightPage,
    required this.blendWidth,
    this.color,
    this.colorBlendMode,
  });

  final ui.Image image;
  final ReaderSpreadAlignment alignment;
  final FilterQuality filterQuality;
  final bool invertColors;
  final bool rightPage;
  final double blendWidth;
  final Color? color;
  final BlendMode? colorBlendMode;
  Size? _size;
  ui.Vertices? _mesh;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_size != size || _mesh == null) {
      const columns = 10, rows = 64;
      final xs = <double>{
        for (var col = 0; col <= columns; col++) col / columns,
        rightPage ? .35 : .65,
        if (rightPage && blendWidth > 0) blendWidth / size.width,
      }.toList()..sort();
      final positions = <Offset>[];
      final texture = <Offset>[];
      final colors = <Color>[];
      void vertex(int col, int row) {
        final x = xs[col], y = row / rows;
        final inner = alignment.strength(x, rightPage: rightPage);
        positions.add(
          Offset(
            x * size.width + (rightPage ? 0 : inner * blendWidth),
            y * size.height,
          ),
        );
        texture.add(
          Offset(
            x * image.width,
            alignment.sourceY(x, y, rightPage: rightPage) * image.height,
          ),
        );
        colors.add(
          Color.fromRGBO(
            255,
            255,
            255,
            rightPage
                ? inner *
                      (blendWidth > 0
                          ? (x * size.width / blendWidth).clamp(0.0, 1.0)
                          : 1)
                : (inner * 1.25).clamp(0.0, 1.0),
          ),
        );
      }

      for (var row = 0; row < rows; row++) {
        for (var col = 0; col + 1 < xs.length; col++) {
          vertex(col, row);
          vertex(col + 1, row);
          vertex(col + 1, row + 1);
          vertex(col, row);
          vertex(col + 1, row + 1);
          vertex(col, row + 1);
        }
      }
      _mesh = ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: texture,
        colors: colors,
      );
      _size = size;
    }
    final shader = ui.ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
      filterQuality: filterQuality,
    );
    final paint = Paint()
      ..isAntiAlias = false
      ..shader = shader;
    if (color != null)
      paint.colorFilter = ColorFilter.mode(
        color!,
        colorBlendMode ?? BlendMode.srcIn,
      );
    if (invertColors) {
      canvas.saveLayer(
        Rect.fromLTWH(
          0,
          0,
          size.width + (rightPage ? 0 : blendWidth),
          size.height,
        ),
        Paint()
          ..colorFilter = const ColorFilter.matrix([
            -1,
            0,
            0,
            0,
            255,
            0,
            -1,
            0,
            0,
            255,
            0,
            0,
            -1,
            0,
            255,
            0,
            0,
            0,
            1,
            0,
          ]),
      );
    }
    canvas.drawVertices(_mesh!, BlendMode.modulate, paint);
    if (invertColors) canvas.restore();
    shader.dispose();
  }

  @override
  bool shouldRepaint(_ReaderSpreadWarpPainter old) =>
      old.image != image ||
      old.alignment != alignment ||
      old.filterQuality != filterQuality ||
      old.invertColors != invertColors ||
      old.rightPage != rightPage ||
      old.blendWidth != blendWidth ||
      old.color != color ||
      old.colorBlendMode != colorBlendMode;
}
