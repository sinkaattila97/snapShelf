import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/shot.dart';
import '../util/io_bridge.dart' as io;

/// Renders a shot from local file (native) or in-memory bytes (web).
class ShotImage extends StatelessWidget {
  const ShotImage({
    super.key,
    required this.shot,
    this.bytes,
    this.fit = BoxFit.cover,
  });

  final Shot shot;
  final Uint8List? bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = shot.localPath;

    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(
        bytes!,
        fit: fit,
        errorBuilder: (_, _, _) => _fallback(scheme),
      );
    }

    if (!kIsWeb && path != null && io.fileExistsSync(path)) {
      return Image(
        image: io.fileImageProvider(path),
        fit: fit,
        errorBuilder: (_, _, _) => _fallback(scheme),
      );
    }

    return _fallback(scheme);
  }

  Widget _fallback(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image_outlined, color: scheme.primary, size: 48),
      ),
    );
  }
}
