import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
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
  static const String currentVersion = '1.5.5';

  // GitHub repository for auto updates
  static String githubRepo = 'hemantyadav1317-boop/Shop-app-POS';
  static String fallbackRepo = '';

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
    return await _checkRepo(repo);
  }

  static Future<UpdateInfo?> _checkRepo(String repo) async {
    // 1. Try official GitHub JSON API with 15-second timeout
    try {
      final url = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
      final res = await http.get(
        url,
        headers: {
          'User-Agent': 'ShopPOS-App',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 15));

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
      }
    } catch (e) {
      debugPrint("Update check API error: $e");
    }

    // 2. High-reliability fallback: GitHub Web Release Redirect (No API Rate Limit!)
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse('https://github.com/$repo/releases/latest'))..followRedirects = false;
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 15));
      final location = streamedResponse.headers['location'];
      if (location != null && location.contains('/releases/tag/')) {
        final tagName = location.split('/releases/tag/').last.trim().replaceAll('v', '');
        final hasNew = isNewerVersion(currentVersion, tagName);
        final downloadUrl = 'https://github.com/$repo/releases/download/v$tagName/ShopPOS-Release.apk';
        return UpdateInfo(
          hasUpdate: hasNew,
          currentVersion: currentVersion,
          latestVersion: tagName,
          downloadUrl: downloadUrl,
          releaseNotes: 'नया अपडेट v$tagName उपलब्ध है।',
        );
      }
    } catch (e) {
      debugPrint("Update check redirect fallback error: $e");
    }

    return null;
  }

  /// Optional override for tests to inject mock OTA progress events
  @visibleForTesting
  static Stream<OtaEvent> Function(String apkUrl, String destinationFilename)?
      otaStreamFactory;

  static bool _isOtaDownloadActive = false;

  /// Whether an in-app APK download is currently running
  @visibleForTesting
  static bool get isOtaDownloadActive => _isOtaDownloadActive;

  /// Resets static download state (primarily for tests)
  @visibleForTesting
  static void resetOtaState() {
    _isOtaDownloadActive = false;
  }

  /// Starts downloading the APK directly inside the app with a live progress dialog
  static void startInAppDownload(BuildContext context, String apkUrl) {
    if (_isOtaDownloadActive) return;
    _isOtaDownloadActive = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _OtaDownloadDialog(
        apkUrl: apkUrl,
        onFinished: () {
          _isOtaDownloadActive = false;
        },
      ),
    ).then((_) {
      _isOtaDownloadActive = false;
    });
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
            onPressed: () {
              Navigator.pop(ctx);
              startInAppDownload(context, info.downloadUrl);
            },
          ),
        ],
      ),
    );
  }
}

class _OtaDownloadDialog extends StatefulWidget {
  final String apkUrl;
  final VoidCallback onFinished;

  const _OtaDownloadDialog({
    required this.apkUrl,
    required this.onFinished,
  });

  @override
  State<_OtaDownloadDialog> createState() => _OtaDownloadDialogState();
}

class _OtaDownloadDialogState extends State<_OtaDownloadDialog> {
  double _progress = 0.0;
  String _statusText = 'डाउनलोड शुरू हो रहा है...';
  bool _hasStarted = false;
  bool _isClosing = false;
  StreamSubscription<OtaEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _startDownloadOnce();
  }

  void _startDownloadOnce() {
    if (_hasStarted) return;
    _hasStarted = true;

    try {
      final stream = UpdateService.otaStreamFactory != null
          ? UpdateService.otaStreamFactory!(
              widget.apkUrl,
              'ShopPOS-Update.apk',
            )
          : OtaUpdate().execute(
              widget.apkUrl,
              destinationFilename: 'ShopPOS-Update.apk',
            );

      _subscription = stream.listen(
        (OtaEvent event) {
          if (!mounted || _isClosing) return;

          if (event.status == OtaStatus.DOWNLOADING) {
            final percent = (double.tryParse(event.value ?? '0') ?? 0)
                .clamp(0.0, 100.0);
            setState(() {
              _progress = percent / 100.0;
              _statusText = 'डाउनलोड हो रहा है: ${percent.toInt()}%';
            });
          } else if (event.status == OtaStatus.INSTALLING) {
            _isClosing = true;
            setState(() {
              _progress = 1.0;
              _statusText = 'इंस्टॉल हो रहा है... 🚀';
            });
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.of(context).pop();
              }
              widget.onFinished();
            });
          } else if (event.status == OtaStatus.ALREADY_RUNNING_ERROR) {
            setState(() {
              _statusText = 'डाउनलोड पहले से चल रहा है...';
            });
          } else {
            _fallbackToBrowser('OTA status: ${event.status}');
          }
        },
        onError: (Object error) {
          _fallbackToBrowser('OTA stream error: $error');
        },
      );
    } catch (e) {
      _fallbackToBrowser('OTA execute error: $e');
    }
  }

  void _fallbackToBrowser(String reason) {
    if (_isClosing) return;
    _isClosing = true;
    debugPrint(reason);
    _subscription?.cancel();
    _subscription = null;

    if (mounted) {
      Navigator.of(context).pop();
    }
    widget.onFinished();

    final uri = Uri.tryParse(widget.apkUrl);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    widget.onFinished();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.downloading, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'अपडेट डाउनलोड हो रहा है',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _statusText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: AppColors.primarySurface,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 12),
          const Text(
            'डाउनलोड पूरा होते ही यह अपने आप इंस्टॉल हो जाएगा। कृपया ऐप बंद न करें।',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _fallbackToBrowser('User chose browser download'),
          child: const Text('Browser से डाउनलोड करें'),
        ),
      ],
    );
  }
}
