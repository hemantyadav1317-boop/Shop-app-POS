import 'package:flutter/material.dart';
import '../../../core/services/sound_service.dart';

class BarcodeScannerDialog extends StatefulWidget {
  final ValueChanged<String> onBarcodeScanned;

  const BarcodeScannerDialog({super.key, required this.onBarcodeScanned});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final TextEditingController _barcodeCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitBarcode(String code) {
    final clean = code.trim();
    if (clean.isEmpty) return;
    SoundService.instance.playBeep();
    widget.onBarcodeScanned(clean);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFF59E0B), size: 28),
              SizedBox(width: 10),
              Text(
                'Barcode Scanner & Search',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Scan with Bluetooth / USB barcode scanner gun or enter 13-digit EAN code:',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _barcodeCtrl,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            onSubmitted: _submitBarcode,
            decoration: InputDecoration(
              hintText: 'e.g. 8901058852448 (Maggi)',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFFF59E0B)),
                onPressed: () => _submitBarcode(_barcodeCtrl.text),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Quick FMCG Samples (Tap to Test):',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSampleChip('🍜 Maggi 70g (₹15)', '8901058852448'),
              _buildSampleChip('🧂 Tata Salt 1kg (₹28)', '8901030381014'),
              _buildSampleChip('🍪 Parle-G 100g (₹10)', '8901719101018'),
              _buildSampleChip('🧈 Amul Butter 100g (₹60)', '8901262010052'),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSampleChip(String label, String barcode) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFFFEF3C7),
      side: const BorderSide(color: Color(0xFFFDE68A)),
      onPressed: () => _submitBarcode(barcode),
    );
  }
}
