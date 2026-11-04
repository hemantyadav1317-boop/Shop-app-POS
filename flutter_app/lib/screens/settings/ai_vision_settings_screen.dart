import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/services/ai_speech_service.dart';
import '../../core/services/ai_vision_catalog.dart';
import '../../core/services/remote_camera_service.dart';
import '../../core/services/sound_service.dart';
import '../../providers/ai_vision_provider.dart';

class AiVisionSettingsScreen extends StatefulWidget {
  const AiVisionSettingsScreen({super.key});

  @override
  State<AiVisionSettingsScreen> createState() => _AiVisionSettingsScreenState();
}

class _AiVisionSettingsScreenState extends State<AiVisionSettingsScreen> {
  final TextEditingController _ipCtrl = TextEditingController();
  bool _isTestingIp = false;
  bool? _ipTestResult;
  bool _isBroadcasting = false;
  String? _broadcastUrl;

  @override
  void initState() {
    super.initState();
    final ai = context.read<AiVisionProvider>();
    _ipCtrl.text = ai.remoteCameraUrl;
    _isBroadcasting = RemoteCameraService.instance.isBroadcasting;
    _broadcastUrl = RemoteCameraService.instance.streamUrl;
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _testRemoteIp() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;

    setState(() {
      _isTestingIp = true;
      _ipTestResult = null;
    });

    final ok = await RemoteCameraService.instance.pingRemoteCamera(ip);
    if (mounted) {
      setState(() {
        _isTestingIp = false;
        _ipTestResult = ok;
      });
      if (ok) {
        SoundService.instance.playSuccess();
        context.read<AiVisionProvider>().setCameraSource(
              AiCameraSource.remotePhoneNode,
              remoteUrl: ip,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Text('✓ रिमोट फोन कैमरा सफलतापूर्वक कनेक्ट हुआ!'),
          ),
        );
      } else {
        SoundService.instance.playAiAmbiguousAlert();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            content: Text('रिमोट कैमरे से कनेक्ट नहीं हो सका। IP और वाई-फाई जांचें।'),
          ),
        );
      }
    }
  }

  Future<void> _toggleBroadcaster() async {
    SoundService.instance.playButtonClick();
    if (_isBroadcasting) {
      await RemoteCameraService.instance.stopBroadcaster();
      setState(() {
        _isBroadcasting = false;
        _broadcastUrl = null;
      });
    } else {
      final ok = await RemoteCameraService.instance.startBroadcaster();
      if (ok && mounted) {
        setState(() {
          _isBroadcasting = true;
          _broadcastUrl = RemoteCameraService.instance.streamUrl;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiVisionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI विज़न व स्मार्ट कैमरा सेटिंग्स'),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF00875A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Master Toggle
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              activeColor: const Color(0xFF10B981),
              title: const Text(
                'AI ऑटो-बिलिंग (Smart Produce Vision)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: const Text(
                'कांटे पर वजन स्थिर होते ही कैमरा फल/सब्जी पहचान कर कार्ट में जोड़ेगा',
                style: TextStyle(fontSize: 12),
              ),
              value: ai.isAiVisionActive,
              onChanged: (val) {
                SoundService.instance.playButtonClick();
                ai.toggleAiVision(val);
              },
            ),
          ),
          const SizedBox(height: 16),

          // 2. Voice Feedback Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            ai.voiceFeedbackEnabled ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded,
                            color: ai.voiceFeedbackEnabled ? const Color(0xFF10B981) : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'वॉइस फीडबैक (Voice Speech)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      Switch(
                        activeColor: const Color(0xFF10B981),
                        value: ai.voiceFeedbackEnabled,
                        onChanged: (val) {
                          SoundService.instance.playButtonClick();
                          ai.setVoiceFeedbackEnabled(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'सामान कार्ट में जुड़ने पर बोलकर बताएगा (उदा. "आलू 1.5 किलो ₹45 जुड़ा")',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (ai.voiceFeedbackEnabled) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.volume_down_rounded, size: 18, color: Colors.grey),
                        Expanded(
                          child: Slider(
                            value: AiSpeechService.instance.volume,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (v) {
                              AiSpeechService.instance.setVolume(v);
                              setState(() {});
                            },
                          ),
                        ),
                        const Icon(Icons.volume_up_rounded, size: 18, color: Colors.grey),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('आवाज़ टेस्ट करें'),
                        onPressed: () {
                          AiSpeechService.instance.speakItemAdded(
                            itemName: 'टमाटर',
                            weightKg: 1.25,
                            totalPrice: 50.0,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Camera Source Selector (Local vs Remote Phone)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'कैमरा स्त्रोत (Camera Source)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'चुनें कि कैमरा इसी डिवाइस का इस्तेमाल करना है या कांटे के ऊपर लगे दूसरे मोबाइल का',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  RadioListTile<AiCameraSource>(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF10B981),
                    title: const Text('यह मोबाइल / टैबलेट (Local Device Camera)'),
                    subtitle: const Text('कांटे के ऊपर स्टैंड पर लगे इसी फोन का कैमरा'),
                    value: AiCameraSource.localDevice,
                    groupValue: ai.cameraSource,
                    onChanged: (val) {
                      if (val != null) {
                        SoundService.instance.playButtonClick();
                        ai.setCameraSource(val);
                      }
                    },
                  ),
                  RadioListTile<AiCameraSource>(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF10B981),
                    title: const Text('दूसरा फोन - कैमरा नोड (Remote Phone Camera)'),
                    subtitle: const Text('टैबलेट काउंटर पर है और दूसरा फोन कांटे पर लगा है'),
                    value: AiCameraSource.remotePhoneNode,
                    groupValue: ai.cameraSource,
                    onChanged: (val) {
                      if (val != null) {
                        SoundService.instance.playButtonClick();
                        ai.setCameraSource(val);
                      }
                    },
                  ),

                  // Remote IP Input
                  if (ai.cameraSource == AiCameraSource.remotePhoneNode) ...[
                    const Divider(height: 24),
                    const Text(
                      'रिमोट फोन का IP एड्रेस दर्ज करें:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ipCtrl,
                            decoration: InputDecoration(
                              hintText: 'उदा. 192.168.1.15:8080',
                              prefixIcon: const Icon(Icons.link_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: _isTestingIp ? null : _testRemoteIp,
                          child: _isTestingIp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('टेस्ट करें'),
                        ),
                      ],
                    ),
                    if (_ipTestResult != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _ipTestResult! ? '✓ कनेक्शन सफल' : '✗ कनेक्शन विफल',
                          style: TextStyle(
                            color: _ipTestResult! ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. "Make This Device a Camera Node" (For the phone mounted over the scale)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.camera_indoor_rounded, color: Color(0xFF38BDF8), size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'इस फोन को "कैमरा नोड" बनाएं (Camera Broadcaster)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'अगर यह फोन कांटे के ऊपर लगा है, तो इसे ऑन करें। आपका काउंटर वाला टैबलेट इससे जुड़ जाएगा।',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isBroadcasting ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(_isBroadcasting ? Icons.stop_rounded : Icons.wifi_tethering_rounded),
                      label: Text(
                        _isBroadcasting ? 'कैमरा ब्रॉडकास्ट रोकें' : 'कैमरा ब्रॉडकास्ट शुरू करें',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _toggleBroadcaster,
                    ),
                  ),
                  if (_isBroadcasting && _broadcastUrl != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'टैबलेट में यह IP एड्रेस डालें:',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _broadcastUrl!,
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: QrImageView(
                              data: _broadcastUrl!,
                              version: QrVersions.auto,
                              size: 140,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '💡 बिना किसी ऐप के: कांटे वाले मोबाइल के Google Chrome में यह लिंक खोलें या QR कोड स्कैन करें!',
                            style: TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. Supported Produce Catalog Preview (30+ items)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: ExpansionTile(
              leading: const Icon(Icons.eco_rounded, color: Color(0xFF10B981)),
              title: Text(
                'सपोर्टेड फल व सब्जियां (${AiVisionCatalog.allItems.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('AI इन सभी भारतीय सामानों को पहचानने में सक्षम है', style: TextStyle(fontSize: 11)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AiVisionCatalog.allItems.map((item) {
                      return Chip(
                        avatar: Text(item.icon, style: const TextStyle(fontSize: 14)),
                        label: Text(
                          '${item.hindiName} (${item.englishName})',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
