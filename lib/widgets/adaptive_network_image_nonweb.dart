import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

Widget buildAdaptiveNetworkImage({
  required String url,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
  Widget? error,
  double? width,
  double? height,
  BorderRadius? borderRadius,
}) {
  final image = CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    width: width,
    height: height,
    placeholder: placeholder != null ? (_, __) => placeholder : null,
    errorWidget: error != null ? (_, __, ___) => error : null,
  );

  if (borderRadius != null) {
    return ClipRRect(borderRadius: borderRadius, child: image);
  }
  return image;
}
