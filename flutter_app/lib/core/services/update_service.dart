import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  static const String currentVersion = '1.0.0';

  // GitHub repository endpoint for auto updates
  static String githubRepo = 'Vinay0775/pos-yadavstore';

  /// Compares semantic versions (e.g., '1.0.1' > '1.0.0')
  static bool isNewerVersion(String current, String latest) {
    try {
      final curParts = current.replaceAll('v', '').split('.').map(int.parse).toList();
      final latParts = latest.replaceAll('v', '').split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final cur = i < curParts.length ? curParts[i] : 0;
        final lat = i < latParts.length ? latParts[i] : 0;
        if (lat > cur) return true;
        if (lat < cur) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Checks if a new release is available on GitHub
  static Future<UpdateInfo?> checkForUpdate({String? customRepo}) async {
    final repo = customRepo ?? githubRepo;
    try {
      final url = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
      final res = await http.get(
        url,
        headers: {
          'User-Agent': 'ShopPOS-App',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final tagName = (data['tag_name'] as String? ?? '').replaceAll('v', '');
        final body = data['body'] as String? ?? 'नया सुधार और फीचर्स जोड़े गए हैं।';

        // Find APK download asset if present
        String downloadUrl = data['html_url'] as String? ?? 'https://github.com/$repo/releases';
        final assets = data['assets'] as List?;
        if (assets != null && assets.isNotEmpty) {
          final apkAsset = assets.firstWhere(
            (a) => (a['name'] as String? ?? '').endsWith('.apk'),
            orElse: () => assets.first,
          );
          downloadUrl = apkAsset['browser_download_url'] as String? ?? downloadUrl;
        }

        final hasNew = isNewerVersion(currentVersion, tagName);
        return UpdateInfo(
          hasUpdate: hasNew,
          currentVersion: currentVersion,
          latestVersion: tagName,
          downloadUrl: downloadUrl,
          releaseNotes: body,
        );
      } else if (res.statusCode == 404) {
        // 404 on GitHub means no newer release exists yet
        return UpdateInfo(
          hasUpdate: false,
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          downloadUrl: 'https://github.com/$repo/releases',
          releaseNotes: 'आप नवीनतम वर्जन पर हैं।',
        );
      }
    } catch (e) {
      debugPrint("Update check error: $e");
    }
    return null;
  }

  /// Displays the update dialog ONLY when a new version is available
  static void showUpdateDialogIfNeeded(BuildContext context, {bool showIfNoUpdate = false}) async {
    final info = await checkForUpdate();

    if (!context.mounted) return;

    if (info == null) {
      if (showIfNoUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('सर्वर से संपर्क नहीं हो पाया। कृपया बाद में प्रयास करें।'),
          ),
        );
      }
      return;
    }

    if (!info.hasUpdate) {
      if (showIfNoUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('🎉 आपका ऐप नवीनतम वर्जन (v${info.currentVersion}) पर है! कोई नया अपडेट पेंडिंग नहीं है।'),
          ),
        );
      }
      return;
    }

    // New update is available - show popup
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'नया अपडेट उपलब्ध है! 🚀',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'नया वर्जन: v${info.latestVersion} (वर्तमान: v${info.currentVersion})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            const Text(
              'इस नए अपडेट में बेहतर परफॉरमेंस, बग फिक्स और नए फीचर्स जोड़े गए हैं।',
              style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
            ),
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lightMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  info.releaseNotes,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('बाद में (Later)'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('अभी अपडेट करें (Update)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(info.downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}
