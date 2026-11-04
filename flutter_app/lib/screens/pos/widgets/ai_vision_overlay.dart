import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../../../core/services/sound_service.dart';
import '../../../providers/ai_vision_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_provider.dart';
import '../../settings/ai_vision_settings_screen.dart';

class AiVisionOverlay extends StatefulWidget {
  const AiVisionOverlay({super.key});

  @override
  State<AiVisionOverlay> createState() => _AiVisionOverlayState();
}

class _AiVisionOverlayState extends State<AiVisionOverlay> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isMinimized = false;
  StreamSubscription? _frameReqSub;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _listenToFrameRequests();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Select back camera
      final backCam = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCam,
        ResolutionPreset.medium, // Optimal balance of speed and recognition
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('AiVisionOverlay camera init error: $e');
    }
  }

  void _listenToFrameRequests() {
    final aiProvider = context.read<AiVisionProvider>();
    _frameReqSub = aiProvider.onFrameRequested.listen((_) async {
      await _captureAndProcessFrame();
    });
  }

  Future<void> _captureAndProcessFrame() async {
    if (_isTakingPicture || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    _isTakingPicture = true;
    try {
      final file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();

      if (mounted) {
        final ai = context.read<AiVisionProvider>();
        final products = context.read<ProductProvider>();
        final cart = context.read<CartProvider>();

        await ai.processFrameBytes(
          bytes,
          weight: ai.pendingWeight,
          productProvider: products,
          cartProvider: cart,
        );
      }
    } catch (e) {
      debugPrint('Failed to capture frame: $e');
    } finally {
      _isTakingPicture = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frameReqSub?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiVisionProvider>();
    if (!ai.isAiVisionActive) return const SizedBox.shrink();

    return Stack(
      children: [
        // 1. Floating Camera PIP Window (Bottom-Right)
        Positioned(
          bottom: 16,
          right: 16,
          child: _isMinimized ? _buildMinimizedPill(ai) : _buildExpandedPip(ai),
        ),

        // 2. High-Priority Ambiguity Choice Bar (When Cucumber vs Kakdi, etc.)
        if (ai.isAmbiguityPending && ai.ambiguousOptions.isNotEmpty)
          Positioned(
            bottom: 180,
            left: 20,
            right: 20,
            child: _buildAmbiguityBanner(ai),
          ),
      ],
    );
  }

  Widget _buildMinimizedPill(AiVisionProvider ai) {
    return InkWell(
      onTap: () {
        SoundService.instance.playButtonClick();
        setState(() => _isMinimized = false);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '📷 AI विज़न',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_full_rounded, color: Colors.white70, size: 14),
            const SizedBox(width: 8),
            // Cut / Close Button
            InkWell(
              onTap: () {
                SoundService.instance.playButtonClick();
                ai.toggleAiVision(false);
              },
              child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedPip(AiVisionProvider ai) {
    return Container(
      width: 170,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ai.isProcessing ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera Live View or Remote status
            ai.cameraSource == AiCameraSource.remotePhoneNode
                ? _buildRemoteCameraView(ai)
                : (_isCameraInitialized && _cameraController != null
                    ? CameraPreview(_cameraController!)
                    : const Center(
                        child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2),
                      )),

            // Viewfinder Targeting Frame
            Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: ai.isProcessing ? Colors.amber : Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Top Control Bar
            Positioned(
              top: 4,
              left: 4,
              right: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Voice speech toggle
                  InkWell(
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      ai.setVoiceFeedbackEnabled(!ai.voiceFeedbackEnabled);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ai.voiceFeedbackEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: ai.voiceFeedbackEnabled ? const Color(0xFF4ADE80) : Colors.white60,
                        size: 15,
                      ),
                    ),
                  ),

                  // Settings
                  InkWell(
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AiVisionSettingsScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.settings_rounded, color: Colors.white, size: 15),
                    ),
                  ),

                  // Minimize
                  InkWell(
                    onTap: () => setState(() => _isMinimized = true),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_fullscreen_rounded, color: Colors.white, size: 15),
                    ),
                  ),

                  // Cut / Close (X) Button
                  InkWell(
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      ai.toggleAiVision(false);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Detection / Status Banner
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                color: Colors.black.withValues(alpha: 0.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ai.isProcessing)
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 1.5),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'पहचान हो रही है...',
                            style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    else if (ai.lastResult != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(ai.lastResult!.item.icon, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${ai.lastResult!.item.hindiName} (${(ai.lastResult!.confidence * 100).toInt()}%)',
                              style: const TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'कांटे पर सामान रखें',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ),

            // Manual Snap Button
            Positioned(
              bottom: 30,
              right: 8,
              child: InkWell(
                onTap: _captureAndProcessFrame,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteCameraView(AiVisionProvider ai) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF38BDF8), size: 36),
          const SizedBox(height: 6),
          const Text(
            'रिमोट फोन कैमरा',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            ai.remoteCameraUrl.isEmpty ? 'IP सेट करें' : ai.remoteCameraUrl,
            style: const TextStyle(color: Colors.white60, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAmbiguityBanner(AiVisionProvider ai) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: Color(0xFFF59E0B), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'कृपया सामान चुनें (Select Correct Produce):',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                InkWell(
                  onTap: ai.dismissAmbiguityPrompt,
                  child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: ai.ambiguousOptions.map((item) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                        ),
                      ),
                      onPressed: () {
                        SoundService.instance.playButtonClick();
                        ai.resolveAmbiguousChoice(
                          selectedItem: item,
                          productProvider: context.read<ProductProvider>(),
                          cartProvider: context.read<CartProvider>(),
                        );
                      },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item.icon, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text(
                              item.hindiName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList()..add(
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.amber, width: 1.5),
                        ),
                      ),
                      onPressed: () {
                        SoundService.instance.playButtonClick();
                        ai.dismissAmbiguityPrompt();
                      },
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded, size: 16, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              'अन्य सामान (Other)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
