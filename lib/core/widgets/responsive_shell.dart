import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ResponsiveShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveShell({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    final width = MediaQuery.of(context).size.width;
    if (kIsWeb || width > maxWidth) {
      final effectivePadding =
          padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
      return Center(
        child: Padding(
          padding: effectivePadding,
          child: content,
        ),
      );
    }

    return child;
  }
}
