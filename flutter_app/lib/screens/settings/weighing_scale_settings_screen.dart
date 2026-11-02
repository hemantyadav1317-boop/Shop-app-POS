import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bluetooth_classic/models/device.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/scale_data_parser.dart';
import '../../providers/weighing_scale_provider.dart';

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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Text('⚖️ ', style: TextStyle(fontSize: 20)),
            Text(
              'Electronic Weighing Scale',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 📟 1. Digital LED Scale Display (Live Meter)
          _buildLcdDisplay(scale, isDark),

          const SizedBox(height: 16),

          // 🔌 2. Bluetooth Connection Card
          _buildConnectionCard(scale, isDark),

          const SizedBox(height: 16),

          // ⚙️ 3. Scale Protocol & Compatibility Card
          _buildProtocolCard(scale, isDark),

          const SizedBox(height: 16),

          // ⚡ 4. Smart Automation Settings Card
          _buildAutomationCard(scale, isDark),

          const SizedBox(height: 16),

          // 🧪 5. Live Simulation / Quick Testing Bar
          _buildSimulationCard(scale, isDark),

          const SizedBox(height: 16),

          // ℹ️ 6. Universal Scale Pairing Instructions
          _buildInstructionsCard(isDark),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // 1. LCD DIGITAL SCALE DISPLAY
  // ==========================================
  Widget _buildLcdDisplay(WeighingScaleProvider scale, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scale.isConnected
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : Colors.white12,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: scale.isConnected
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : Colors.black26,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row: Status badges & Tare button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scale.isConnected
                          ? const Color(0xFF10B981)
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    scale.isConnected ? 'ONLINE' : 'DISCONNECTED',
                    style: TextStyle(
                      color: scale.isConnected
                          ? const Color(0xFF10B981)
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Stability indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scale.isStable
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: scale.isStable
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      scale.isStable ? 'STABLE' : 'MEASURING...',
                      style: TextStyle(
                        color: scale.isStable
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // TARE / ZERO button
                  InkWell(
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      scale.tare();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF3B82F6),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restart_alt_rounded, color: Color(0xFF60A5FA), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'ZERO / TARE',
                            style: TextStyle(
                              color: Color(0xFF93C5FD),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Main weight readout (Green LED style)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                scale.liveWeight.toStringAsFixed(3),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF34D399),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'KG',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6EE7B7),
                ),
              ),
            ],
          ),

          // Secondary Grams & Billing indicator badge
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Text(
                '= ${scale.liveWeightGrams.toStringAsFixed(0)} g • Kirana Billing Qty: ${scale.liveWeight.toStringAsFixed(3)} kg',
                style: const TextStyle(
                  color: Color(0xFFA7F3D0),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Raw stream monitor badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.grey, size: 14),
                const SizedBox(width: 6),
                const Text(
                  'RAW DATA: ',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                Expanded(
                  child: Text(
                    scale.rawStreamData,
                    style: const TextStyle(
                      color: Color(0xFFA7F3D0),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. BLUETOOTH CONNECTION CARD
  // ==========================================
  Widget _buildConnectionCard(WeighingScaleProvider scale, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bluetooth_connected_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bluetooth Scale Connection',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Connect via Bluetooth Classic SPP (9600 Baud)',
                        style: TextStyle(color: Colors.grey, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            if (scale.isConnected) ...[
              // Connected Scale Tile
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scale.scaleName ?? 'Electronic Scale',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            scale.scaleMac ?? 'Connected',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        SoundService.instance.playButtonClick();
                        final name = scale.scaleName ?? 'Weighing Scale';
                        scale.disconnectScale();
                        _showConnectionMessage(
                          context,
                          title: 'Disconnected',
                          message: '$name has been disconnected.',
                          isSuccess: false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Connect Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: scale.isConnecting ? null : () => _showDevicePicker(context, scale),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00875A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: scale.isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(
                    scale.isConnecting ? 'Connecting...' : 'Scan & Connect Weighing Scale',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],

            if (!scale.isHardwareSupported) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hardware Bluetooth is optimized for Android phones. On Web & PC, simulation mode is active for live testing.',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. PROTOCOL SELECTOR CARD
  // ==========================================
  Widget _buildProtocolCard(WeighingScaleProvider scale, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scale Protocol / Brand Format',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select specific brand format if Auto-Detect doesn\'t read your scale',
              style: TextStyle(color: Colors.grey, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ScaleProtocol>(
                  value: scale.protocol,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: const [
                    DropdownMenuItem(
                      value: ScaleProtocol.autoDetect,
                      child: Text('Universal Auto-Detect (Recommended)'),
                    ),
                    DropdownMenuItem(
                      value: ScaleProtocol.phoenixNitiraj,
                      child: Text('Phoenix / Nitiraj (ST,GS,+00.000kg)'),
                    ),
                    DropdownMenuItem(
                      value: ScaleProtocol.essae,
                      child: Text('Essae-Teraoka (STX...ETX Protocol)'),
                    ),
                    DropdownMenuItem(
                      value: ScaleProtocol.casEagle,
                      child: Text('Eagle / CAS (WN00.000kg)'),
                    ),
                    DropdownMenuItem(
                      value: ScaleProtocol.standardSpp,
                      child: Text('Generic Serial / HC-05 Continuous'),
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
            const Divider(height: 28),
            const Text(
              'Weight Unit & Decimal Calibration',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'How raw numbers from your scale are converted to Kilograms for billing',
              style: TextStyle(color: Colors.grey, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ScaleUnitMode>(
                  value: scale.unitMode,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: const [
                    DropdownMenuItem(
                      value: ScaleUnitMode.autoDetect,
                      child: Text('Smart Auto: 540g / 540 count ➔ 0.540 kg (Recommended)'),
                    ),
                    DropdownMenuItem(
                      value: ScaleUnitMode.gramsToKg,
                      child: Text('Grams ÷ 1000 (For 3-decimal scales without dot: 540 ➔ 0.540 kg)'),
                    ),
                    DropdownMenuItem(
                      value: ScaleUnitMode.directKg,
                      child: Text('Direct Kilograms (For scales sending dot: 0.540 ➔ 0.540 kg)'),
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
      ),
    );
  }

  // ==========================================
  // 4. SMART AUTOMATION SETTINGS
  // ==========================================
  Widget _buildAutomationCard(WeighingScaleProvider scale, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              'Auto-Fill Weight in Item Dialog',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: const Text(
              'When opening potato, onion, or tomato, default quantity to live scale weight',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            activeColor: const Color(0xFF00875A),
            value: scale.autoFillDialog,
            onChanged: (val) {
              SoundService.instance.playButtonClick();
              scale.toggleAutoFill(val);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text(
              'Zero-Touch Mandi Fast Mode',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: const Text(
              'Tapping a produce item instantly bills it with current stable weight',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            activeColor: const Color(0xFF00875A),
            value: scale.autoAddOnStable,
            onChanged: (val) {
              SoundService.instance.playButtonClick();
              scale.toggleAutoAdd(val);
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. LIVE SIMULATION & TESTING
  // ==========================================
  Widget _buildSimulationCard(WeighingScaleProvider scale, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Hardware Test & Weight Simulator',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                    style: TextStyle(color: Color(0xFF6366F1), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Inject weights to verify live billing in Vegetable POS without hardware connected.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),

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
                _buildQuickSimChip(scale, '5.000 kg', 5.000),
                _buildQuickSimChip(scale, 'Tare (0kg)', 0.000, isTare: true),
              ],
            ),

            const SizedBox(height: 12),

            // Weight Slider
            Row(
              children: [
                const Text('Weight:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  // ==========================================
  // 6. PAIRING INSTRUCTIONS
  // ==========================================
  Widget _buildInstructionsCard(bool isDark) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        title: const Text(
          'How to Connect Any Bluetooth Kaanta (कांटा)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        leading: const Icon(Icons.help_outline_rounded, color: Color(0xFF00875A)),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: const [
          Text(
            '1. Turn ON the power switch on your electronic weighing scale.\n'
            '2. Open your Android phone Settings > Bluetooth.\n'
            '3. Pair your scale device (typically named HC-05, SCALE, PHOENIX, ESSAE, or BT-KAANTA).\n'
            '4. Enter the Bluetooth PIN if prompted (usually 1234 or 0000).\n'
            '5. Return to this screen, tap "Scan & Connect Weighing Scale", and select your paired scale.\n'
            '6. Weight will now stream live in the vegetable POS screen instantly!',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DEVICE PICKER BOTTOM SHEET
  // ==========================================
  Future<void> _showDevicePicker(
    BuildContext context,
    WeighingScaleProvider scale,
  ) async {
    List<Device> devices = [];
    try {
      devices = await scale.getPairedDevices();
      // Bring currently connected scale to the top of list
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
                          color: const Color(0xFF00875A).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bluetooth_searching, color: Color(0xFF00875A), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Paired Scale',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Tap your electronic scale to connect',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
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
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.bluetooth_disabled_rounded, size: 44, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No paired Bluetooth devices found.\nPlease pair your weighing scale in Android Settings first.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
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
                            title: 'Demo Scale Connected',
                            message: 'Virtual scale active for testing live weight.',
                            isSuccess: true,
                          );
                        },
                        child: const Text('Connect Virtual Demo Scale'),
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
                              : 'Bluetooth Weighing Scale';
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
                            cardBg = const Color(0xFF00875A).withValues(alpha: 0.08);
                            cardBorder = const Color(0xFF00875A).withValues(alpha: 0.5);
                          } else {
                            cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
                            cardBorder = Colors.grey.withValues(alpha: 0.2);
                          }

                          return InkWell(
                            onTap: () async {
                              if (connectingAddress != null) return;

                              if (isConnected) {
                                Navigator.pop(ctx);
                                _showConnectionMessage(
                                  context,
                                  title: 'Already Connected',
                                  message: 'Scale "$name" is already connected and active.',
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
                                // Wait 600ms so the user sees the green CONNECTED badge
                                await Future.delayed(const Duration(milliseconds: 600));
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  _showConnectionMessage(
                                    context,
                                    title: 'Connected Successfully!',
                                    message: 'Connected with $name. Live weight reading is active for billing.',
                                    isSuccess: true,
                                  );
                                }
                              } else {
                                SoundService.instance.playError();
                                _showConnectionMessage(
                                  context,
                                  title: 'Connection Failed',
                                  message: 'Could not connect to $name. Please check if scale is powered ON.',
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
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cardBorder, width: isConnected || isConnectingThis ? 2.0 : 1.0),
                                boxShadow: isConnected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // Leading Status Icon / Spinner
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
                                    Icon(
                                      Icons.scale_rounded,
                                      color: isSelected ? const Color(0xFF00875A) : Colors.grey,
                                      size: 26,
                                    ),
                                  const SizedBox(width: 14),

                                  // Device Name & MAC Address
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                            color: isConnected
                                                ? const Color(0xFF10B981)
                                                : (isConnectingThis ? const Color(0xFF2563EB) : null),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isConnectingThis ? 'Connecting via Bluetooth SPP...' : address,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isConnectingThis ? const Color(0xFF3B82F6) : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Trailing Status Pill
                                  if (isConnected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'CONNECTED ✓',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.5,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    )
                                  else if (isConnectingThis)
                                    const Text(
                                      'Connecting...',
                                      style: TextStyle(
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

  // ==========================================
  // ELEGANT FLOATING CONNECTION MESSAGE BANNER
  // ==========================================
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
