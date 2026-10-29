import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ProductImageView extends StatelessWidget {
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

    Widget imageContent;

    if (hasImage) {
      final url = imageUrl!.trim();
      if (url.startsWith('data:image')) {
        try {
          final commaIndex = url.indexOf(',');
          final base64Data = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
          final bytes = base64Decode(base64Data);
          imageContent = Image.memory(
            bytes,
            width: w,
            height: h,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          );
        } catch (_) {
          imageContent = _buildFallback();
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.lightMuted,
          borderRadius: BorderRadius.circular(borderRadius),
          border: borderRadius > 0 ? Border.all(color: AppColors.lightBorder, width: 0.5) : null,
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
