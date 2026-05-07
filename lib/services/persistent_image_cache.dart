import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PersistentImageCache {
  PersistentImageCache._();

  static final PersistentImageCache instance = PersistentImageCache._();

  final http.Client _client = http.Client();
  final Map<String, Future<File?>> _downloads = {};
  final Map<String, File> _memoryFiles = {};

  Future<File?> getFile(String imageUrl) {
    final parsed = _parseImageUrl(imageUrl);
    if (parsed == null) {
      return Future.value(null);
    }

    final (:normalizedUrl, :uri) = parsed;
    final cachedFile = memoryFile(normalizedUrl);
    if (cachedFile != null) return Future.value(cachedFile);

    final existingDownload = _downloads[normalizedUrl];
    if (existingDownload != null) return existingDownload;

    final download = _getOrDownload(uri, normalizedUrl);
    _downloads[normalizedUrl] = download;

    return download.whenComplete(() {
      if (identical(_downloads[normalizedUrl], download)) {
        _downloads.remove(normalizedUrl);
      }
    });
  }

  File? memoryFile(String? imageUrl) {
    final normalizedUrl = imageUrl?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty) return null;

    final file = _memoryFiles[normalizedUrl];
    if (file == null) return null;

    if (!file.existsSync() || file.lengthSync() == 0) {
      _memoryFiles.remove(normalizedUrl);
      return null;
    }

    return file;
  }

  Future<File?> getExistingFile(String? imageUrl) async {
    final parsed = _parseImageUrl(imageUrl);
    if (parsed == null) return null;

    final (:normalizedUrl, :uri) = parsed;
    final cachedFile = memoryFile(normalizedUrl);
    if (cachedFile != null) return cachedFile;

    try {
      final cacheFile = await _cacheFileFor(uri, normalizedUrl);
      if (await cacheFile.exists() && await cacheFile.length() > 0) {
        _memoryFiles[normalizedUrl] = cacheFile;
        return cacheFile;
      }
    } catch (_) {}

    return null;
  }

  Future<void> warm(String? imageUrl) async {
    final normalizedUrl = imageUrl?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty) return;

    try {
      await getFile(normalizedUrl);
    } catch (_) {
      // A cache miss should never block the real image widget fallback.
    }
  }

  Future<void> rememberExisting(Iterable<String?> imageUrls) async {
    await Future.wait(imageUrls.map(getExistingFile));
  }

  void warmAll(Iterable<String?> imageUrls) {
    for (final imageUrl in imageUrls) {
      warm(imageUrl);
    }
  }

  Future<void> evict(String? imageUrl) async {
    final parsed = _parseImageUrl(imageUrl);
    if (parsed == null) {
      return;
    }

    final (:normalizedUrl, :uri) = parsed;
    _downloads.remove(normalizedUrl);
    _memoryFiles.remove(normalizedUrl);

    try {
      final cacheFile = await _cacheFileFor(uri, normalizedUrl);
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    } catch (_) {
      // Eviction is best-effort; a future render can still refresh the file.
    }
  }

  Future<File?> _getOrDownload(Uri uri, String normalizedUrl) async {
    final cacheFile = await _cacheFileFor(uri, normalizedUrl);

    if (await cacheFile.exists() && await cacheFile.length() > 0) {
      _memoryFiles[normalizedUrl] = cacheFile;
      return cacheFile;
    }

    final tempFile = File('${cacheFile.path}.download');

    try {
      final response = await _client.get(
        uri,
        headers: const {'Accept': 'image/*,*/*'},
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        return null;
      }

      await tempFile.writeAsBytes(response.bodyBytes, flush: true);

      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }

      final savedFile = await tempFile.rename(cacheFile.path);
      _memoryFiles[normalizedUrl] = savedFile;
      return savedFile;
    } catch (_) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      return null;
    }
  }

  ({String normalizedUrl, Uri uri})? _parseImageUrl(String? imageUrl) {
    final normalizedUrl = imageUrl?.trim();
    final uri = normalizedUrl == null ? null : Uri.tryParse(normalizedUrl);

    if (normalizedUrl == null ||
        normalizedUrl.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty) {
      return null;
    }

    return (normalizedUrl: normalizedUrl, uri: uri);
  }

  Future<File> _cacheFileFor(Uri uri, String normalizedUrl) async {
    final supportDir = await getApplicationSupportDirectory();
    final cacheDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}image_cache',
    );

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return File(
      '${cacheDir.path}${Platform.pathSeparator}${_cacheKey(normalizedUrl)}${_extensionFor(uri)}',
    );
  }

  String _cacheKey(String value) {
    var hash = 0x811c9dc5;

    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return '${value.length}_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  String _extensionFor(Uri uri) {
    if (uri.pathSegments.isEmpty) return '.img';

    final fileName = uri.pathSegments.last.toLowerCase();
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '.img';
    }

    final extension = fileName.substring(dotIndex + 1);
    const imageExtensions = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'heic',
      'heif',
    };

    if (!imageExtensions.contains(extension)) {
      return '.img';
    }

    return '.$extension';
  }
}
