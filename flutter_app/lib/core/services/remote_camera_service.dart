import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RemoteCameraService {
  RemoteCameraService._();
  static final RemoteCameraService instance = RemoteCameraService._();

  HttpServer? _server;
  Uint8List? _latestFrameBytes;
  bool _isBroadcasting = false;
  String? _localIp;
  int _port = 8080;

  bool get isBroadcasting => _isBroadcasting;
  String? get localIp => _localIp;
  int get port => _port;
  String get streamUrl => _localIp != null ? 'http://$_localIp:$_port' : '';

  /// Updates the latest frame to be served to remote clients
  void updateLatestFrame(Uint8List jpegBytes) {
    _latestFrameBytes = jpegBytes;
  }

  /// Starts broadcasting camera snapshots on local Wi-Fi / Hotspot
  Future<bool> startBroadcaster({int port = 8080}) async {
    if (_isBroadcasting) return true;
    _port = port;
    try {
      // Find local WiFi/Hotspot IPv4 address
      _localIp = await _getLocalIpAddress();

      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isBroadcasting = true;
      debugPrint('RemoteCameraService listening on http://$_localIp:$_port');

      _server!.listen((HttpRequest request) async {
        final path = request.uri.path;
        request.response.headers.add('Access-Control-Allow-Origin', '*');

        if (path == '/snapshot' || path == '/shot.jpg') {
          if (_latestFrameBytes != null && _latestFrameBytes!.isNotEmpty) {
            request.response.headers.contentType = ContentType('image', 'jpeg');
            request.response.add(_latestFrameBytes!);
          } else {
            request.response.statusCode = HttpStatus.noContent;
          }
        } else if (path == '/upload' && request.method == 'POST') {
          final bytes = <int>[];
          await for (final chunk in request) {
            bytes.addAll(chunk);
          }
          if (bytes.isNotEmpty) {
            _latestFrameBytes = Uint8List.fromList(bytes);
            request.response.statusCode = HttpStatus.ok;
            request.response.write('{"status":"ok"}');
          } else {
            request.response.statusCode = HttpStatus.badRequest;
          }
        } else if (path == '/cam' || path == '/') {
          request.response.headers.contentType = ContentType.html;
          request.response.write(_buildBrowserCameraHtml());
        } else if (path == '/status' || path == '/ping') {
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"status":"online","type":"shoppos_camera_node","port":$_port}');
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('ShopPOS Camera Node Active');
        }
        await request.response.close();
      });

      return true;
    } catch (e) {
      debugPrint('Failed to start RemoteCameraService: $e');
      _isBroadcasting = false;
      return false;
    }
  }

  /// Stops broadcasting
  Future<void> stopBroadcaster() async {
    try {
      await _server?.close(force: true);
      _server = null;
      _isBroadcasting = false;
    } catch (_) {}
  }

  /// Client Mode: Fetches snapshot from remote camera IP (e.g. tablet fetching from phone)
  Future<Uint8List?> fetchRemoteSnapshot(String remoteIpOrUrl) async {
    try {
      String url = remoteIpOrUrl.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      if (!url.contains('/snapshot') && !url.contains('/shot.jpg')) {
        url = '$url/snapshot';
      }

      final res = await http.get(Uri.parse(url)).timeout(const Duration(milliseconds: 2000));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
    } catch (e) {
      debugPrint('fetchRemoteSnapshot error: $e');
    }
    return null;
  }

  /// Client Mode: Pings remote camera to verify connection
  Future<bool> pingRemoteCamera(String remoteIpOrUrl) async {
    try {
      String url = remoteIpOrUrl.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      if (!url.contains('/status') && !url.contains('/ping')) {
        url = '$url/status';
      }

      final res = await http.get(Uri.parse(url)).timeout(const Duration(milliseconds: 1500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  String _buildBrowserCameraHtml() {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>ShopPOS Scale Camera</title>
  <style>
    body { background: #0f172a; color: white; font-family: -apple-system, BlinkMacSystemFont, sans-serif; text-align: center; margin: 0; padding: 16px; }
    h2 { margin: 8px 0; font-size: 18px; color: #38bdf8; }
    p { font-size: 12px; color: #94a3b8; margin-top: 0; }
    video { width: 100%; max-width: 440px; border-radius: 14px; border: 2.5px solid #10b981; box-shadow: 0 4px 20px rgba(0,0,0,0.5); transform: scaleX(-1); }
    .badge { background: #10b981; color: white; padding: 8px 16px; border-radius: 20px; font-weight: bold; display: inline-block; margin-top: 14px; font-size: 13px; }
    .footer { font-size: 11px; color: #64748b; margin-top: 20px; }
  </style>
</head>
<body>
  <h2>📷 ShopPOS स्केल कैमरा नोड</h2>
  <p>यह फोन कांटे के ऊपर लगा है और टैबलेट में लाइव फोटो भेज रहा है</p>
  <video id="v" autoplay playsinline muted></video>
  <canvas id="c" style="display:none"></canvas>
  <br>
  <div class="badge" id="st">कैमरा शुरू हो रहा है...</div>
  <div class="footer">ShopPOS AI Vision • Zero-Install Web Camera</div>

  <script>
    const v = document.getElementById('v');
    const c = document.getElementById('c');
    const st = document.getElementById('st');

    navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: 'environment' }, width: { ideal: 640 }, height: { ideal: 640 } },
      audio: false
    })
    .then(stream => {
      v.srcObject = stream;
      st.innerText = '✓ टैबलेट से सफलतापूर्वक कनेक्टेड (लाइव)';
      st.style.background = '#10b981';
      setInterval(() => {
        if (v.videoWidth > 0) {
          c.width = 320;
          c.height = 320;
          c.getContext('2d').drawImage(v, 0, 0, 320, 320);
          c.toBlob(blob => {
            if (blob) {
              fetch('/upload', { method: 'POST', body: blob }).catch(() => {});
            }
          }, 'image/jpeg', 0.65);
        }
      }, 400);
    })
    .catch(err => {
      st.innerText = 'कैमरा परमिशन दें: ' + err.message;
      st.style.background = '#dc2626';
    });
  </script>
</body>
</html>''';
  }
}
