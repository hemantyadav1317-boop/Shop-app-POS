import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bluetooth_classic/models/device.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/scale_data_parser.dart';
import '../../core/services/bluetooth_device_classifier.dart';
import '../../providers/weighing_scale_provider.dart';
import '../../providers/locale_provider.dart';

class WeighingScaleSettingsScreen extends StatefulWidget {
  const WeighingScaleSettingsScreen({super.key});

  @override
  State<WeighingScaleSettingsScreen> createState() =>
      _WeighingScaleSettingsScreenState();
}

class _WeighingScaleSettingsScreenState
    extends State<WeighingScaleSettingsScreen> {
  double _simSliderWeight = 1.250;

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<WeighingScaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeCode = context.watch<LocaleProvider>().localeCode;
    final isHindi = localeCode == 'hi';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF5722), Color(0xFFF97316)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            SoundService.instance.playButtonClick();
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            const Icon(Icons.scale_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              isHindi ? 'इलेक्ट्रॉनिक तौल कांटा' : 'Electronic Weighing Scale',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
            tooltip: isHindi ? 'कांटा जानकारी' : 'Scale Info',
            onPressed: () => _showInstructionsSheet(context, isDark, isHindi),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 850 : double.infinity),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                children: [
                  // 📟 1. Hero Digital LED Scale Display (Matching Reference Image 1)
                  _buildHeroLcdDisplay(scale, isDark, isHindi),

                  const SizedBox(height: 14),

                  // 🔌 2. Bluetooth Scale Connection Card
                  _buildConnectionCard(scale, isDark, isHindi),

                  const SizedBox(height: 14),

                  // ⚙️ 3. Scale Protocol / Brand Format Card
                  _buildProtocolCard(scale, isDark, isHindi),

                  const SizedBox(height: 14),

                  // 🎯 4. Weight Unit & Decimal Calibration Card
                  _buildCalibrationCard(scale, isDark, isHindi),

                  const SizedBox(height: 14),

                  // ⚡ 5. Bottom 2 Toggle Cards (Responsive: Side-by-Side on wide or 2 cards)
                  _buildAutomationCards(scale, isDark, isHindi, constraints.maxWidth),

                  const SizedBox(height: 14),

                  // 🧪 6. Live Simulation & Hardware Test Bar
                  _buildSimulationCard(scale, isDark, isHindi),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 1. HERO DIGITAL LED SCALE DISPLAY (IMAGE 1)
  // ==========================================
  Widget _buildHeroLcdDisplay(WeighingScaleProvider scale, bool isDark, bool isHindi) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF070B14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scale.isConnected
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : Colors.white12,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Status Row: Dot + Status (left) & Pill + Stable (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Online / Disconnected indicator
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scale.isConnected
                          ? const Color(0xFF10B981)
                          : const Color(0xFF10B981), // matching mockup green dot
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    scale.isConnected
                        ? (isHindi ? 'कनेक्टेड' : 'Connected')
                        : (isHindi ? 'डिस्कनेक्टेड' : 'Disconnected'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),

              // Right: Stable pill badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scale.isStable
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scale.isStable
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      scale.isStable ? Icons.check_circle_rounded : Icons.sync_rounded,
                      color: scale.isStable ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      scale.isStable
                          ? (isHindi ? 'स्थिर' : 'Stable')
                          : (isHindi ? 'तोल रहे हैं...' : 'Measuring...'),
                      style: TextStyle(
                        color: scale.isStable
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Main Center Area: Weighing Scale Machine Graphic + Giant Digital Numbers
          Row(
            children: [
              // Weighing Scale Graphic Illustration
              _buildScaleMachineIllustration(),

              const SizedBox(width: 16),

              // Giant Weight Display
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      scale.liveWeight.toStringAsFixed(3),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'KG',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF7A00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bottom Bar: Tare + Kirana Billing Qty
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.balance_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  'Tare : ${scale.liveWeightGrams > 0 ? "0" : "0"} g   |   ${isHindi ? "किराना बिलिंग मात्रा" : "Kirana Billing Qty"} : ${scale.liveWeight.toStringAsFixed(3)} kg',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Visual 3D-like scale illustration widget
  Widget _buildScaleMachineIllustration() {
    return Container(
      width: 80,
      height: 75,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Platform base
          Positioned(
            bottom: 8,
            child: Container(
              width: 64,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF475569),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
          // Metallic plate top
          Positioned(
            bottom: 24,
            child: Container(
              width: 58,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Pole
          Positioned(
            bottom: 24,
            left: 20,
            child: Container(
              width: 4,
              height: 26,
              color: const Color(0xFF94A3B8),
            ),
          ),
          // Digital Head Indicator
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              width: 32,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1),
              ),
              alignment: Alignment.center,
              child: const Text(
                '0.000',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. BLUETOOTH SCALE CONNECTION CARD
  // ==========================================
  Widget _buildConnectionCard(WeighingScaleProvider scale, bool isDark, bool isHindi) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Row with Blue squircle icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bluetooth_rounded,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'ब्लूटूथ कांटा कनेक्शन' : 'Bluetooth Scale Connection',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHindi
                          ? 'ब्लूटूथ क्लासिक SPP (9600 Baud) द्वारा कनेक्ट करें'
                          : 'Connect via Bluetooth Classic SPP (9600 Baud)',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
            ],
          ),

          const SizedBox(height: 14),

          // Action: Connected details or Orange Scan button
          if (scale.isConnected) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scale.scaleName ?? (isHindi ? 'तौल कांटा' : 'Electronic Scale'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Color(0xFF166534),
                          ),
                        ),
                        Text(
                          scale.scaleMac ?? (isHindi ? 'कनेक्टेड' : 'Connected'),
                          style: const TextStyle(color: Color(0xFF15803D), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      SoundService.instance.playButtonClick();
                      final name = scale.scaleName ?? (isHindi ? 'तौल कांटा' : 'Weighing Scale');
                      scale.disconnectScale();
                      _showConnectionMessage(
                        context,
                        title: isHindi ? 'डिस्कनेक्ट हुआ' : 'Disconnected',
                        message: isHindi ? '$name सफलतापूर्वक डिस्कनेक्ट हो गया।' : '$name has been disconnected.',
                        isSuccess: false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: Text(isHindi ? 'डिस्कनेक्ट' : 'Disconnect', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: scale.isConnecting ? null : () => _showDevicePicker(context, scale, isHindi),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: scale.isConnecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_searching_rounded, size: 20),
                label: Text(
                  scale.isConnecting
                      ? (isHindi ? 'कनेक्ट हो रहा है...' : 'Connecting...')
                      : (isHindi ? 'तौल कांटा खोजें और जोड़ें' : 'Scan & Connect Weighing Scale'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 3. PROTOCOL / BRAND FORMAT CARD
  // ==========================================
  Widget _buildProtocolCard(WeighingScaleProvider scale, bool isDark, bool isHindi) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFFF97316),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'कांटा प्रोटोकॉल / ब्रांड फॉर्मेट' : 'Scale Protocol / Brand Format',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHindi
                          ? 'यदि कांटा अपने आप न पढ़े तो विशिष्ट ब्रांड चुनें'
                          : 'Select specific brand format if Auto-Detect doesn’t read your scale',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Dropdown Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ScaleProtocol>(
                value: scale.protocol,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                items: [
                  DropdownMenuItem(
                    value: ScaleProtocol.autoDetect,
                    child: Text(
                      isHindi ? 'यूनिवर्सल ऑटो-डिटेक्ट (अनुशंसित)' : 'Universal Auto-Detect (Recommended)',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: ScaleProtocol.phoenixNitiraj,
                    child: Text('Phoenix / Nitiraj (ST,GS,+00.000kg)', style: TextStyle(fontSize: 13.5)),
                  ),
                  const DropdownMenuItem(
                    value: ScaleProtocol.essae,
                    child: Text('Essae-Teraoka (STX...ETX)', style: TextStyle(fontSize: 13.5)),
                  ),
                  const DropdownMenuItem(
                    value: ScaleProtocol.casEagle,
                    child: Text('Eagle / CAS (WN00.000kg)', style: TextStyle(fontSize: 13.5)),
                  ),
                  const DropdownMenuItem(
                    value: ScaleProtocol.standardSpp,
                    child: Text('Generic Serial / HC-05 Continuous', style: TextStyle(fontSize: 13.5)),
                  ),
                ],
                onChanged: (newProtocol) {
                  if (newProtocol != null) {
                    SoundService.instance.playButtonClick();
                    scale.setProtocol(newProtocol);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. WEIGHT UNIT & DECIMAL CALIBRATION CARD
  // ==========================================
  Widget _buildCalibrationCard(WeighingScaleProvider scale, bool isDark, bool isHindi) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.gps_fixed_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'वजन इकाई व दशमलव कैलिब्रेशन' : 'Weight Unit & Decimal Calibration',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHindi
                          ? 'कांटे से प्राप्त कच्चे अंकों को बिलिंग किलोग्राम में बदलने का तरीका'
                          : 'How raw numbers from your scale are converted to Kilograms for billing',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Dropdown Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ScaleUnitMode>(
                value: scale.unitMode,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                items: [
                  DropdownMenuItem(
                    value: ScaleUnitMode.autoDetect,
                    child: Text(
                      isHindi
                          ? 'स्मार्ट ऑटो: 540g ➔ 0.540 kg (अनुशंसित)'
                          : 'Smart Auto: 540g / 540 count ➔ 0.540 kg (Recommended)',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  DropdownMenuItem(
                    value: ScaleUnitMode.gramsToKg,
                    child: Text(
                      isHindi
                          ? 'ग्राम ÷ 1000 (बिना दशमलव वाले कांटे: 540 ➔ 0.540 kg)'
                          : 'Grams ÷ 1000 (For 3-decimal scales without dot: 540 ➔ 0.540 kg)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  DropdownMenuItem(
                    value: ScaleUnitMode.directKg,
                    child: Text(
                      isHindi
                          ? 'सीधा किलोग्राम (दशमलव वाले कांटे: 0.540 ➔ 0.540 kg)'
                          : 'Direct Kilograms (For scales sending dot: 0.540 ➔ 0.540 kg)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
                onChanged: (newMode) {
                  if (newMode != null) {
                    SoundService.instance.playButtonClick();
                    scale.setUnitMode(newMode);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. BOTTOM 2 TOGGLE CARDS (IMAGE 1)
  // ==========================================
  Widget _buildAutomationCards(
    WeighingScaleProvider scale,
    bool isDark,
    bool isHindi,
    double maxWidth,
  ) {
    final card1 = Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFBBF7D0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.scale_rounded, color: Color(0xFF16A34A), size: 20),
              ),
              Switch(
                value: scale.autoFillDialog,
                activeThumbColor: const Color(0xFF10B981),
                activeTrackColor: const Color(0xFFA7F3D0),
                onChanged: (val) {
                  SoundService.instance.playButtonClick();
                  scale.toggleAutoFill(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isHindi ? 'सामान चुनते ही वजन भरें' : 'Auto-Fill Weight in Item Dialog',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isHindi
                ? 'आलू, प्याज या टमाटर खोलते ही लाइव वजन अपने आप भर जाएगा'
                : 'When opening potato, onion, or tomato, default quantity to live scale weight',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
              height: 1.3,
            ),
          ),
        ],
      ),
    );

    final card2 = Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFBFDBFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              Switch(
                value: scale.autoAddOnStable,
                activeThumbColor: const Color(0xFF10B981),
                activeTrackColor: const Color(0xFFA7F3D0),
                onChanged: (val) {
                  SoundService.instance.playButtonClick();
                  scale.toggleAutoAdd(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isHindi ? 'जीरो-टच मंडी फास्ट मोड' : 'Zero-Touch Mandi Fast Mode',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isHindi
                ? 'सब्जी पर क्लिक करते ही स्थिर वजन के साथ तुरंत बिल में जुड़ जाएगा'
                : 'Tapping a produce item instantly bills it with current stable weight',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
              height: 1.3,
            ),
          ),
        ],
      ),
    );

    if (maxWidth > 650) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: card1),
          const SizedBox(width: 14),
          Expanded(child: card2),
        ],
      );
    }

    return Column(
      children: [
        card1,
        const SizedBox(height: 12),
        card2,
      ],
    );
  }

  // ==========================================
  // 6. LIVE SIMULATION & HARDWARE TEST BAR
  // ==========================================
  Widget _buildSimulationCard(WeighingScaleProvider scale, bool isDark, bool isHindi) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              Text(
                isHindi ? 'हार्डवेयर टेस्ट व वजन सिमुलेटर' : 'Hardware Test & Weight Simulator',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TEST TOOL',
                  style: TextStyle(color: Color(0xFF6366F1), fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick weight chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickSimChip(scale, '0.250 kg', 0.250),
              _buildQuickSimChip(scale, '0.500 kg', 0.500),
              _buildQuickSimChip(scale, '1.000 kg', 1.000),
              _buildQuickSimChip(scale, '1.500 kg', 1.500),
              _buildQuickSimChip(scale, '2.500 kg', 2.500),
              _buildQuickSimChip(scale, 'Tare (0kg)', 0.000, isTare: true),
            ],
          ),

          const SizedBox(height: 10),

          // Weight Slider
          Row(
            children: [
              Text(
                isHindi ? 'वजन:' : 'Weight:',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Slider(
                  value: _simSliderWeight,
                  min: 0.0,
                  max: 10.0,
                  divisions: 100,
                  label: '${_simSliderWeight.toStringAsFixed(3)} kg',
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (val) {
                    setState(() => _simSliderWeight = val);
                    scale.simulateWeight(val, isStable: true);
                  },
                ),
              ),
              Text(
                '${_simSliderWeight.toStringAsFixed(3)} kg',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSimChip(
    WeighingScaleProvider scale,
    String label,
    double weight, {
    bool isTare = false,
  }) {
    final isCurrent = (scale.liveWeight - weight).abs() < 0.001;
    return ActionChip(
      label: Text(label),
      backgroundColor: isCurrent
          ? const Color(0xFF10B981).withValues(alpha: 0.2)
          : (isTare ? Colors.red.withValues(alpha: 0.1) : null),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: isCurrent
            ? const Color(0xFF10B981)
            : (isTare ? Colors.red : null),
      ),
      side: BorderSide(
        color: isCurrent
            ? const Color(0xFF10B981)
            : (isTare ? Colors.red.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3)),
      ),
      onPressed: () {
        SoundService.instance.playButtonClick();
        setState(() => _simSliderWeight = weight);
        scale.simulateWeight(weight, isStable: true);
      },
    );
  }

  // Instructions Bottom Sheet
  void _showInstructionsSheet(BuildContext context, bool isDark, bool isHindi) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: Color(0xFFFF5722), size: 22),
                const SizedBox(width: 8),
                Text(
                  isHindi ? 'ब्लूटूथ कांटा जोड़ने की विधि' : 'How to Connect Any Bluetooth Scale',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isHindi
                  ? '1. अपने इलेक्ट्रॉनिक तौल कांटे का स्विच ऑन करें।\n'
                    '2. मोबाइल सेटिंग्स > ब्लूटूथ में जाएं और कांटे को पेयर करें।\n'
                    '3. पिन कोड मांगे तो 1234 या 0000 दर्ज करें।\n'
                    '4. इस स्क्रीन पर आकर "तौल कांटा खोजें और जोड़ें" दबाएं।\n'
                    '5. अब सब्जी व फल बिलिंग में वजन अपने आप लाइव चलेगा!'
                  : '1. Turn ON the power switch on your electronic weighing scale.\n'
                    '2. Open your phone Settings > Bluetooth and pair the scale.\n'
                    '3. Enter Bluetooth PIN if prompted (usually 1234 or 0000).\n'
                    '4. Return here, tap "Scan & Connect Weighing Scale" and select your scale.\n'
                    '5. Live weight reading is now active for billing!',
              style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DEVICE PICKER BOTTOM SHEET
  // ==========================================
  Future<void> _showDevicePicker(
    BuildContext context,
    WeighingScaleProvider scale,
    bool isHindi,
  ) async {
    List<Device> devices = [];
    try {
      devices = await scale.getPairedDevices();
      if (scale.scaleMac != null && devices.isNotEmpty) {
        devices.sort((a, b) {
          if (a.address == scale.scaleMac) return -1;
          if (b.address == scale.scaleMac) return 1;
          return 0;
        });
      }
    } catch (e) {
      debugPrint("Error getting paired devices: $e");
    }

    if (!context.mounted) return;

    String? connectingAddress;
    String? selectedAddress = scale.scaleMac;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5722).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bluetooth_searching, color: Color(0xFFFF5722), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHindi ? 'पेयर्ड तौल कांटा चुनें' : 'Select Paired Scale',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              isHindi ? 'कनेक्ट करने के लिए अपने कांटे पर क्लिक करें' : 'Tap your electronic scale to connect',
                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  if (devices.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.bluetooth_disabled_rounded, size: 44, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              isHindi
                                  ? 'कोई पेयर्ड ब्लूटूथ डिवाइस नहीं मिला।\nकृपया पहले मोबाइल सेटिंग्स में जाकर कांटा जोड़ें।'
                                  : 'No paired Bluetooth devices found.\nPlease pair your weighing scale in phone Settings first.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          scale.connectToScale('SIM:00:11:22:33', name: 'Virtual Bluetooth Scale');
                          _showConnectionMessage(
                            context,
                            title: isHindi ? 'डेमो कांटा कनेक्ट हुआ' : 'Demo Scale Connected',
                            message: isHindi ? 'वजन परीक्षण के लिए वर्चुअल कांटा सक्रिय है।' : 'Virtual scale active for testing live weight.',
                            isSuccess: true,
                          );
                        },
                        child: Text(isHindi ? 'वर्चुअल डेमो कांटा जोड़ें' : 'Connect Virtual Demo Scale'),
                      ),
                    ),
                  ] else ...[
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        itemBuilder: (listCtx, i) {
                          final d = devices[i];
                          final name = (d.name != null && d.name!.isNotEmpty)
                              ? d.name!
                              : (isHindi ? 'ब्लूटूथ तौल कांटा' : 'Bluetooth Weighing Scale');
                          final address = d.address;
                          final isConnected = scale.isConnected && (scale.scaleMac == address);
                          final isConnectingThis = connectingAddress == address;
                          final isSelected = isConnected || (selectedAddress == address);

                          Color cardBg;
                          Color cardBorder;
                          if (isConnected) {
                            cardBg = const Color(0xFF10B981).withValues(alpha: 0.14);
                            cardBorder = const Color(0xFF10B981);
                          } else if (isConnectingThis) {
                            cardBg = const Color(0xFF2563EB).withValues(alpha: 0.12);
                            cardBorder = const Color(0xFF3B82F6);
                          } else if (isSelected) {
                            cardBg = const Color(0xFFFF5722).withValues(alpha: 0.08);
                            cardBorder = const Color(0xFFFF5722).withValues(alpha: 0.5);
                          } else {
                            cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
                            cardBorder = Colors.grey.withValues(alpha: 0.2);
                          }

                          final devInfo = BluetoothDeviceClassifier.classify(name, address);

                          return InkWell(
                            onTap: () async {
                              if (connectingAddress != null) return;

                              if (isConnected) {
                                Navigator.pop(ctx);
                                _showConnectionMessage(
                                  context,
                                  title: isHindi ? 'पहले से कनेक्टेड है' : 'Already Connected',
                                  message: isHindi ? '$name पहले से चालू है।' : 'Scale "$name" is already connected and active.',
                                  isSuccess: true,
                                );
                                return;
                              }

                              setModalState(() {
                                connectingAddress = address;
                                selectedAddress = address;
                              });
                              SoundService.instance.playButtonClick();

                              final ok = await scale.connectToScale(address, name: name);
                              if (!context.mounted) return;

                              setModalState(() {
                                connectingAddress = null;
                              });

                              if (ok) {
                                SoundService.instance.playSuccess();
                                await Future.delayed(const Duration(milliseconds: 600));
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  _showConnectionMessage(
                                    context,
                                    title: isHindi ? 'सफलतापूर्वक कनेक्ट हुआ!' : 'Connected Successfully!',
                                    message: isHindi ? '$name के साथ लाइव वजन बिलिंग चालू है।' : 'Connected with $name. Live weight reading is active.',
                                    isSuccess: true,
                                  );
                                }
                              } else {
                                SoundService.instance.playError();
                                _showConnectionMessage(
                                  context,
                                  title: isHindi ? 'कनेक्ट नहीं हो सका' : 'Connection Failed',
                                  message: isHindi ? '$name से कनेक्ट नहीं हुआ। कृपया कांटा ऑन रखें।' : 'Could not connect to $name. Please check if scale is powered ON.',
                                  isSuccess: false,
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                    : (devInfo.isRecommendedForScale
                                        ? const Color(0xFFEFF6FF)
                                        : cardBg),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isConnected
                                      ? const Color(0xFF10B981)
                                      : (devInfo.isRecommendedForScale ? const Color(0xFF60A5FA) : cardBorder),
                                  width: isConnected || isConnectingThis || devInfo.isRecommendedForScale ? 2.0 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (isConnectingThis)
                                    const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Color(0xFF2563EB),
                                      ),
                                    )
                                  else if (isConnected)
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 26)
                                  else
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundColor: devInfo.backgroundColor,
                                      child: Icon(
                                        devInfo.icon,
                                        color: devInfo.primaryColor,
                                        size: 17,
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isConnected
                                                ? const Color(0xFF10B981)
                                                : (isConnectingThis ? const Color(0xFF2563EB) : null),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isConnectingThis
                                              ? (isHindi ? 'ब्लूटूथ SPP द्वारा कनेक्ट हो रहा है...' : 'Connecting via Bluetooth SPP...')
                                              : address,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isConnectingThis ? const Color(0xFF3B82F6) : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isConnected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isHindi ? 'कनेक्टेड ✓' : 'CONNECTED ✓',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    )
                                  else if (isConnectingThis)
                                    Text(
                                      isHindi ? 'कनेक्ट हो रहा है...' : 'Connecting...',
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showConnectionMessage(
    BuildContext context, {
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
