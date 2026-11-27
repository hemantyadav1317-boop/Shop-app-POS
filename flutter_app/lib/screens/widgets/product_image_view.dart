import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/local_image_cache_service.dart';

class ProductImageView extends StatelessWidget {
  static final Map<String, Uint8List> _base64BytesCache = <String, Uint8List>{};
  static const int _maxBase64CacheEntries = 80;

  static Uint8List _decodeBase64Cached(String dataUrl) {
    final existing = _base64BytesCache[dataUrl];
    if (existing != null) return existing;
    final commaIndex = dataUrl.indexOf(',');
    final base64Data =
        commaIndex != -1 ? dataUrl.substring(commaIndex + 1) : dataUrl;
    final decoded = base64Decode(base64Data);
    if (_base64BytesCache.length >= _maxBase64CacheEntries) {
      _base64BytesCache.remove(_base64BytesCache.keys.first);
    }
    _base64BytesCache[dataUrl] = decoded;
    return decoded;
  }

  final String? imageUrl;
  final String? fallbackIcon;
  final double size;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;

  const ProductImageView({
    super.key,
    this.imageUrl,
    this.fallbackIcon,
    this.size = 48.0,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final w = width ?? size;
    final h = height ?? size;
    final memCacheSize = (w * 2).clamp(96, 320).toInt();

    Widget imageContent;

    if (hasImage) {
      final url = imageUrl!.trim();
      if (url.startsWith('data:image')) {
        try {
          final bytes = _decodeBase64Cached(url);
          imageContent = Image.memory(
            bytes,
            width: w,
            height: h,
            fit: fit,
            cacheWidth: memCacheSize,
            cacheHeight: memCacheSize,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          );
        } catch (_) {
          imageContent = _buildFallback();
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        if (!kIsWeb) {
          // Check instant offline disk cache first (0ms latency, zero internet)
          final cachedFile = LocalImageCacheService.instance.getCachedFile(url);
          if (cachedFile != null) {
            imageContent = Image.file(
              cachedFile,
              width: w,
              height: h,
              fit: fit,
              cacheWidth: memCacheSize,
              cacheHeight: memCacheSize,
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            );
          } else {
            // First time: fetch in background, save to persistent local disk, and display
            imageContent = _CachedDiskNetworkImage(
              url: url,
              width: w,
              height: h,
              fit: fit,
              memCacheSize: memCacheSize,
              fallback: _buildFallback(),
            );
          }
        } else {
          // Web fallback
          imageContent = Image.network(
            url,
            width: w,
            height: h,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                width: w,
                height: h,
                color: AppColors.lightMuted,
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          );
        }
      } else if (!kIsWeb) {
        // Local file on mobile/desktop
        try {
          final file = File(url);
          if (file.existsSync()) {
            imageContent = Image.file(
              file,
              width: w,
              height: h,
              fit: fit,
              cacheWidth: memCacheSize,
              cacheHeight: memCacheSize,
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            );
          } else {
            imageContent = _buildFallback();
          }
        } catch (_) {
          imageContent = _buildFallback();
        }
      } else {
        imageContent = _buildFallback();
      }
    } else {
      imageContent = _buildFallback();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : AppColors.lightMuted,
          borderRadius: BorderRadius.circular(borderRadius),
          border: borderRadius > 0
              ? Border.all(
                  color: isDark ? const Color(0xFF334155) : AppColors.lightBorder,
                  width: 0.5,
                )
              : null,
        ),
        child: imageContent,
      ),
    );
  }

  Widget _buildFallback() {
    final iconSize = (height != null && height != double.infinity) ? height! * 0.45 : size * 0.45;
    return Center(
      child: Text(
        fallbackIcon ?? '📦',
        style: TextStyle(fontSize: iconSize.clamp(16.0, 48.0)),
      ),
    );
  }
}

/// Seamless background download & persistent disk caching widget
class _CachedDiskNetworkImage extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final int memCacheSize;
  final Widget fallback;

  const _CachedDiskNetworkImage({
    required this.url,
    required this.width,
    required this.height,
    required this.fit,
    required this.memCacheSize,
    required this.fallback,
  });

  @override
  State<_CachedDiskNetworkImage> createState() => _CachedDiskNetworkImageState();
}

class _CachedDiskNetworkImageState extends State<_CachedDiskNetworkImage> {
  File? _file;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void didUpdateWidget(covariant _CachedDiskNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadFile();
    }
  }

  Future<void> _loadFile() async {
    final cached = LocalImageCacheService.instance.getCachedFile(widget.url);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _file = cached;
          _isLoading = false;
        });
      }
      return;
    }

    _file = await LocalImageCacheService.instance.fetchAndCache(widget.url);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_file != null) {
      return Image.file(
        _file!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.memCacheSize,
        cacheHeight: widget.memCacheSize,
        errorBuilder: (ctx, err, stack) => widget.fallback,
      );
    }

    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: AppColors.lightMuted.withValues(alpha: 0.3),
        child: const Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    return widget.fallback;
  }
}
