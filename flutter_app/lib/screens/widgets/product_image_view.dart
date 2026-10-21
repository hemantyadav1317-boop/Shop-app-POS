import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ProductImageView extends StatelessWidget {
  final String? imageUrl;
  final String? fallbackIcon;
  final double size;
  final double borderRadius;
  final BoxFit fit;

  const ProductImageView({
    super.key,
    this.imageUrl,
    this.fallbackIcon,
    this.size = 48.0,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

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
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          );
        } catch (_) {
          imageContent = _buildFallback();
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        imageContent = Image.network(
          url,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              width: size,
              height: size,
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
              width: size,
              height: size,
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
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.lightMuted,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: AppColors.lightBorder, width: 0.5),
        ),
        child: imageContent,
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Text(
        fallbackIcon ?? '📦',
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }
}
