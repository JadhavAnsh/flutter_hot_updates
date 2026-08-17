import 'package:flutter/material.dart';

import '../hot_updates.dart';

/// Text widget backed by a text asset from the active patch or bundle.
class HotTextAsset extends StatelessWidget {
  const HotTextAsset(
    this.assetPath, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fallback = '',
  });

  final String assetPath;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: HotUpdates.assetResolver.readTextAsset(assetPath),
      builder: (context, snapshot) {
        final text = snapshot.data ?? fallback;
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}
