// ignore_for_file: deprecated_member_use

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

Widget buildAdaptiveNetworkImage({
  required String url,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
  Widget? error,
  double? width,
  double? height,
  BorderRadius? borderRadius,
}) {
  return _WebNetworkImage(
    url: url,
    fit: fit,
    placeholder: placeholder,
    error: error,
    width: width,
    height: height,
    borderRadius: borderRadius,
  );
}

class _WebNetworkImage extends StatefulWidget {
  const _WebNetworkImage({
    required this.url,
    required this.fit,
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
  State<_WebNetworkImage> createState() => _WebNetworkImageState();
}

class _WebNetworkImageState extends State<_WebNetworkImage> {
  static int _idCounter = 0;

  late final String _viewType =
      'adaptive-network-image-${_idCounter++}-${DateTime.now().microsecondsSinceEpoch}';

  bool _isLoaded = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      _buildImageElement,
    );
  }

  html.Element _buildImageElement(int viewId) {
    final wrapper =
        html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.overflow = 'hidden'
          ..style.display = 'flex';

    final borderRadiusCss = _borderRadiusCss(widget.borderRadius);
    if (borderRadiusCss != null) {
      wrapper.style.borderRadius = borderRadiusCss;
    }

    final image =
        html.ImageElement()
          ..crossOrigin = 'anonymous'
          ..src = widget.url
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = _objectFitCss(widget.fit)
          ..style.display = 'block';

    if (borderRadiusCss != null) {
      image.style.borderRadius = borderRadiusCss;
    }

    image.onLoad.listen((_) {
      if (!mounted) return;
      setState(() {
        _isLoaded = true;
        _hasError = false;
      });
    });

    image.onError.listen((_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    });

    wrapper.append(image);
    return wrapper;
  }

  @override
  Widget build(BuildContext context) {
    final placeholder =
        widget.placeholder ??
        Container(
          color: Colors.purple.shade50,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );

    final error =
        widget.error ??
        Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
        );

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView(viewType: _viewType),
          if (!_isLoaded && !_hasError) Positioned.fill(child: placeholder),
          if (_hasError) Positioned.fill(child: error),
        ],
      ),
    );
  }

  String? _borderRadiusCss(BorderRadius? radius) {
    if (radius == null) return null;
    final tl = radius.topLeft;
    final tr = radius.topRight;
    final br = radius.bottomRight;
    final bl = radius.bottomLeft;
    return '${tl.x}px ${tr.x}px ${br.x}px ${bl.x}px / ${tl.y}px ${tr.y}px ${br.y}px ${bl.y}px';
  }

  String _objectFitCss(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.cover:
        return 'cover';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitHeight:
        return 'cover';
      case BoxFit.fitWidth:
        return 'cover';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
    }
  }
}
