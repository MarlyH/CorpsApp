import 'dart:io';

import 'package:corpsapp/services/persistent_image_cache.dart';
import 'package:flutter/material.dart';

class PersistentCachedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final WidgetBuilder? placeholderBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  const PersistentCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  State<PersistentCachedImage> createState() => _PersistentCachedImageState();
}

class _PersistentCachedImageState extends State<PersistentCachedImage> {
  File? _cachedFile;
  late Future<File?> _imageFileFuture;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(PersistentCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  void _loadImage() {
    _cachedFile = PersistentImageCache.instance.memoryFile(widget.imageUrl);

    if (_cachedFile != null) {
      _imageFileFuture = Future.value(_cachedFile);
      return;
    }

    _imageFileFuture = PersistentImageCache.instance.getFile(widget.imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final cachedFile = _cachedFile;
    if (cachedFile != null) {
      return _buildImage(cachedFile);
    }

    return FutureBuilder<File?>(
      future: _imageFileFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;

        if (snapshot.connectionState == ConnectionState.done && file != null) {
          _cachedFile = file;
          return _buildImage(file);
        }

        if (snapshot.connectionState == ConnectionState.done) {
          return _buildError(context, snapshot.error);
        }

        return widget.placeholderBuilder?.call(context) ??
            SizedBox(width: widget.width, height: widget.height);
      },
    );
  }

  Widget _buildError(BuildContext context, Object? error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(
        context,
        error ?? Exception('Image unavailable'),
        null,
      );
    }

    return SizedBox(width: widget.width, height: widget.height);
  }

  Widget _buildImage(File file) {
    return Image.file(
      file,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: widget.errorBuilder,
    );
  }
}
