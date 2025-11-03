import 'package:flutter/widgets.dart';

import 'adaptive_network_image_nonweb.dart'
    if (dart.library.html) 'adaptive_network_image_web.dart';

class AdaptiveNetworkImage extends StatelessWidget {
  const AdaptiveNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.error,
    this.width,
    this.height,
    this.borderRadius,
  });

  final String url;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? error;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return buildAdaptiveNetworkImage(
      url: url,
      fit: fit,
      placeholder: placeholder,
      error: error,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}
