import 'package:flutter/material.dart';

import '../hot_updates.dart';

/// Image widget that resolves from the active patch before bundled assets.
class HotImage extends StatelessWidget {
  const HotImage(
    this.assetPath, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.errorBuilder,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider>(
      future: _loadProvider(),
      builder: (context, snapshot) {
        if (snapshot.hasError && errorBuilder != null) {
          return errorBuilder!(
            context,
            snapshot.error ?? 'failed to load image',
            StackTrace.current,
          );
        }

        if (!snapshot.hasData) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Image(
          image: snapshot.data!,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          errorBuilder: errorBuilder,
        );
      },
    );
  }

  Future<ImageProvider> _loadProvider() async {
    final provider = await HotUpdates.assetResolver.resolveImageProvider(assetPath);
    if (provider == null) {
      throw FlutterError('unable to resolve image: $assetPath');
    }
    return provider;
  }
}
