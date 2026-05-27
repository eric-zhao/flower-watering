import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Renders an image at its natural aspect ratio inside an [AspectRatio]
/// container so portrait photos stay tall and landscape photos stay wide,
/// instead of being forced into a fixed-height crop.
///
/// The ratio is clamped to `[minRatio, maxRatio]` so extreme aspect images
/// (panoramas, full-height selfies) don't dominate the layout. When clamped,
/// the image is shown with [BoxFit.cover] — accepting a small crop — so the
/// container doesn't show letterbox bars.
class AdaptiveImage extends StatefulWidget {
  const AdaptiveImage({
    super.key,
    required this.bytes,
    this.borderRadius = 12,
    this.minRatio = 3 / 5,
    this.maxRatio = 16 / 9,
    this.placeholderRatio = 4 / 3,
    this.maxHeight,
  });

  final Uint8List bytes;
  final double borderRadius;
  final double minRatio;
  final double maxRatio;
  final double placeholderRatio;

  /// Optional cap so a tall portrait image doesn't dominate the layout.
  /// When set, portrait photos shrink to fit (becoming narrower than the
  /// parent width, centered).
  final double? maxHeight;

  @override
  State<AdaptiveImage> createState() => _AdaptiveImageState();
}

class _AdaptiveImageState extends State<AdaptiveImage> {
  double? _naturalRatio;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant AdaptiveImage old) {
    super.didUpdateWidget(old);
    if (!identical(old.bytes, widget.bytes)) {
      _naturalRatio = null;
      _decode();
    }
  }

  Future<void> _decode() async {
    if (widget.bytes.isEmpty) return;
    try {
      final img = await decodeImageFromList(widget.bytes);
      if (!mounted) return;
      setState(() => _naturalRatio = img.width / img.height);
    } on Object {
      // Leave _naturalRatio null → fall back to placeholder ratio.
    }
  }

  @override
  Widget build(BuildContext context) {
    final natural = _naturalRatio;
    final ratio = (natural ?? widget.placeholderRatio)
        .clamp(widget.minRatio, widget.maxRatio);
    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AspectRatio(
        aspectRatio: ratio,
        child: Image.memory(
          widget.bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );

    if (widget.maxHeight != null) {
      // ConstrainedBox + Center: portrait images shrink to fit the height cap
      // and sit centered with neutral letterbox space at the sides.
      image = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight!),
        child: Center(child: image),
      );
    }

    return image;
  }
}
