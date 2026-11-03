import 'package:flutter/material.dart';

enum BluetoothDeviceType {
  printer,
  scale,
  audio,
  watch,
  phone,
  computer,
  unknown,
}

class BluetoothDeviceClassification {
  final BluetoothDeviceType type;
  final String label;
  final String badgeText;
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;
  final bool isRecommendedForPrinter;
  final bool isRecommendedForScale;

  const BluetoothDeviceClassification({
    required this.type,
    required this.label,
    required this.badgeText,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
    required this.isRecommendedForPrinter,
    required this.isRecommendedForScale,
  });
}

class BluetoothDeviceClassifier {
  static BluetoothDeviceClassification classify(String? rawName, String? address) {
    final name = (rawName ?? '').trim().toLowerCase();

    // 1. Thermal Printers (POS, Thermal, RPP, MPT, 58mm, 80mm, Epson, TVS, InnerPrinter)
    if (name.contains('print') ||
        name.contains('pos') ||
        name.contains('thermal') ||
        name.contains('rpp') ||
        name.contains('mpt') ||
        name.contains('t58') ||
        name.contains('t80') ||
        name.contains('58mm') ||
        name.contains('80mm') ||
        name.contains('epson') ||
        name.contains('tvs') ||
        name.contains('inner') ||
        name.contains('receipt') ||
        name.contains('bluetooth printer')) {
      return const BluetoothDeviceClassification(
        type: BluetoothDeviceType.printer,
        label: 'प्रिंटर (Thermal Printer)',
        badgeText: '🖨️ प्रिंटर',
        icon: Icons.print_rounded,
        primaryColor: Color(0xFF00875A),
        backgroundColor: Color(0xFFE8F5E9),
        isRecommendedForPrinter: true,
        isRecommendedForScale: false,
      );
    }

    // 2. Weighing Scales (Scale, Weight, Kaanta, Essae, Phoenix, Eagle, Sensod, HC-05, BT-Scale)
    if (name.contains('scale') ||
        name.contains('weight') ||
        name.contains('kaanta') ||
        name.contains('kanta') ||
        name.contains('essae') ||
        name.contains('phoenix') ||
        name.contains('eagle') ||
        name.contains('sensod') ||
        name.contains('hc-05') ||
        name.contains('hc-06') ||
        name.contains('w01') ||
        name.contains('w-01') ||
        name.contains('bt-scale')) {
      return const BluetoothDeviceClassification(
        type: BluetoothDeviceType.scale,
        label: 'इलेक्ट्रॉनिक कांटा (Scale)',
        badgeText: '⚖️ वजन कांटा',
        icon: Icons.scale_rounded,
        primaryColor: Color(0xFF2563EB),
        backgroundColor: Color(0xFFEFF6FF),
        isRecommendedForPrinter: false,
        isRecommendedForScale: true,
      );
    }

    // 3. Audio Devices (Speakers, Headphones, Earphones, Buds, Soundbar)
    if (name.contains('boat') ||
        name.contains('jbl') ||
        name.contains('noise') ||
        name.contains('sound') ||
        name.contains('speaker') ||
        name.contains('buds') ||
        name.contains('airpod') ||
        name.contains('head') ||
        name.contains('ear') ||
        name.contains('rockerz') ||
        name.contains('bass') ||
        name.contains('audio') ||
        name.contains('sony') ||
        name.contains('boult') ||
        name.contains('mivi') ||
        name.contains('realme buds') ||
        name.contains('oppo enco') ||
        name.contains('oneplus buds') ||
        name.contains('bluetooth music') ||
        name.contains('car bt') ||
        name.contains('media')) {
      return const BluetoothDeviceClassification(
        type: BluetoothDeviceType.audio,
        label: 'स्पीकर / हेडसेट (Audio)',
        badgeText: '🎧 स्पीकर',
        icon: Icons.headphones_rounded,
        primaryColor: Color(0xFF64748B),
        backgroundColor: Color(0xFFF1F5F9),
        isRecommendedForPrinter: false,
        isRecommendedForScale: false,
      );
    }

    // 4. Smartwatches & Fitness Bands
    if (name.contains('watch') ||
        name.contains('band') ||
        name.contains('fit') ||
        name.contains('gear') ||
        name.contains('amazfit') ||
        name.contains('fire-boltt') ||
        name.contains('colorfit') ||
        name.contains('dizo') ||
        name.contains('pebble') ||
        name.contains('wear')) {
      return const BluetoothDeviceClassification(
        type: BluetoothDeviceType.watch,
        label: 'स्मार्टवॉच (Watch)',
        badgeText: '⌚ स्मार्टवॉच',
        icon: Icons.watch_rounded,
        primaryColor: Color(0xFF8B5CF6),
        backgroundColor: Color(0xFFF5F3FF),
        isRecommendedForPrinter: false,
        isRecommendedForScale: false,
      );
    }

    // 5. Smartphones & Tablets
    if (name.contains('phone') ||
        name.contains('galaxy') ||
        name.contains('iphone') ||
        name.contains('redmi') ||
        name.contains('realme') ||
        name.contains('oppo') ||
        name.contains('vivo') ||
        name.contains('oneplus') ||
        name.contains('pixel') ||
        name.contains('mi ') ||
        name.contains('samsung') ||
        name.contains('moto') ||
        name.contains('pad') ||
        name.contains('tablet')) {
      return const BluetoothDeviceClassification(
        type: BluetoothDeviceType.phone,
        label: 'मोबाइल फोन (Smartphone)',
        badgeText: '📱 फोन',
        icon: Icons.smartphone_rounded,
        primaryColor: Color(0xFF0284C7),
        backgroundColor: Color(0xFFE0F2FE),
        isRecommendedForPrinter: false,
        isRecommendedForScale: false,
      );
    }

    // 6. Computers & Laptops
    if (name.contains('pc') ||
        name.contains('laptop') ||
        name.contains('desktop') ||
        name.contains('macbook') ||
        name.contains('windows') ||
        name.contains('computer')) {
      return const BluetoothDeviceClassification(
        type: BluetoothDeviceType.computer,
        label: 'कंप्यूटर / लैपटॉप',
        badgeText: '💻 कंप्यूटर',
        icon: Icons.laptop_rounded,
        primaryColor: Color(0xFF475569),
        backgroundColor: Color(0xFFF8FAFC),
        isRecommendedForPrinter: false,
        isRecommendedForScale: false,
      );
    }

    // Default unknown / generic
    return const BluetoothDeviceClassification(
      type: BluetoothDeviceType.unknown,
      label: 'ब्लूटूथ डिवाइस',
      badgeText: '📡 डिवाइस',
      icon: Icons.bluetooth_rounded,
      primaryColor: Color(0xFF6B7280),
      backgroundColor: Color(0xFFF3F4F6),
      isRecommendedForPrinter: false,
      isRecommendedForScale: false,
    );
  }
}
