import 'package:flutter/material.dart';

enum BluetoothDeviceType {
  printer,
  scale,
  audio,
  watch,
  phone,
  computer,
  tv,
  car,
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

    // 1. Thermal Printers (POS, Thermal, RPP, MPT, 58mm, 80mm, Epson, TVS, InnerPrinter, HOIN, XP)
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
        name.contains('xp-') ||
        name.contains('hoin') ||
        name.contains('gprinter') ||
        name.contains('milestone') ||
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

    // 2. Weighing Scales (Scale, Weight, Kaanta, Essae, Phoenix, Eagle, Sensod, HC-05, BT-Scale, CAS, Nitiraj)
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
        name.contains('cas') ||
        name.contains('nitiraj') ||
        name.contains('weigh') ||
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

    // 3. Smart TVs & Streaming Devices (TV, AndroidTV, Fire TV, Mi TV, Bravia, LG, Samsung TV, Vu, TCL, Hisense, etc.)
    if (name.contains('tv') ||
        name.contains('smarttv') ||
        name.contains('androidtv') ||
        name.contains('googletv') ||
        name.contains('google tv') ||
        name.contains('bravia') ||
        name.contains('firetv') ||
        name.contains('fire tv') ||
        name.contains('firestick') ||
        name.contains('fire stick') ||
        name.contains('chromecast') ||
        name.contains('airplay') ||
        name.contains('tcl') ||
        name.contains('hisense') ||
        name.contains('vu tv') ||
        name.contains('vu ') ||
        name.contains('toshiba tv') ||
        name.contains('sansui') ||
        name.contains('thomson') ||
        name.contains('blaupunkt') ||
        name.contains('tizen') ||
        name.contains('webos') ||
        name.contains('set-top') ||
        name.contains('setup box')) {
      return const BluetoothDeviceClassification(
        type: BluetoothDeviceType.tv,
        label: 'स्मार्ट टीवी (Smart TV)',
        badgeText: '📺 टीवी',
        icon: Icons.tv_rounded,
        primaryColor: Color(0xFF7C3AED),
        backgroundColor: Color(0xFFF5F3FF),
        isRecommendedForPrinter: false,
        isRecommendedForScale: false,
      );
    }

    // 4. Smartwatches & Fitness Bands (Watch, Band, ColorFit, Wave, Fire-Boltt, Noise, Titan, Fastrack, Amazfit, Apple Watch, Boult, BeatXP, etc.)
    if (name.contains('watch') ||
        name.contains('iwatch') ||
        name.contains('band') ||
        name.contains('fit') ||
        name.contains('gear') ||
        name.contains('amazfit') ||
        name.contains('fire-boltt') ||
        name.contains('fireboltt') ||
        name.contains('boltt') ||
        name.contains('ninja') ||
        name.contains('colorfit') ||
        name.contains('noisefit') ||
        name.contains('dizo watch') ||
        name.contains('pebble') ||
        name.contains('fastrack') ||
        name.contains('reflex') ||
        name.contains('titan') ||
        name.contains('helix') ||
        name.contains('drift') ||
        name.contains('crown') ||
        name.contains('lunar') ||
        name.contains('boat wave') ||
        name.contains('boat storm') ||
        name.contains('boat xtend') ||
        name.contains('boat lunar') ||
        name.contains('wave ') ||
        name.contains('storm ') ||
        name.contains('xtend') ||
        name.contains('beatxp') ||
        name.contains('crossbeats') ||
        name.contains('gizmore') ||
        name.contains('gizfit') ||
        name.contains('cultsport') ||
        name.contains('wrist') ||
        name.contains('fitness') ||
        name.contains('wear') ||
        name.contains('galaxy watch')) {
      return const BluetoothDeviceClassification(
        type: BluetoothDeviceType.watch,
        label: 'स्मार्टवॉच / बैंड (Watch)',
        badgeText: '⌚ घड़ी/बैंड',
        icon: Icons.watch_rounded,
        primaryColor: Color(0xFF8B5CF6),
        backgroundColor: Color(0xFFF5F3FF),
        isRecommendedForPrinter: false,
        isRecommendedForScale: false,
      );
    }

    // 5. Audio Devices: Speakers & Soundbars (ZEB-, TG-, THRILLER, MOCO, BT-V, Stone, Soundbar, JBL, Sony)
    if (name.contains('zeb') ||
        name.contains('tg-') ||
        name.contains('tg1') ||
        name.contains('thriller') ||
        name.contains('moco') ||
        name.contains('bt-v') ||
        name.contains('v09') ||
        name.contains('speaker') ||
        name.contains('sound') ||
        name.contains('soundbar') ||
        name.contains('boom') ||
        name.contains('stone') ||
        name.contains('party') ||
        name.contains('jbl') ||
        name.contains('marshall') ||
        name.contains('bose') ||
        name.contains('harman') ||
        name.contains('infinity') ||
        name.contains('portronics') ||
        name.contains('intex') ||
        name.contains('iball') ||
        name.contains('spk')) {
      return const BluetoothDeviceClassification(
        type: BluetoothDeviceType.audio,
        label: 'ब्लूटूथ स्पीकर (Speaker)',
        badgeText: '🔊 स्पीकर',
        icon: Icons.speaker_rounded,
        primaryColor: Color(0xFFEA580C),
        backgroundColor: Color(0xFFFFF7ED),
        isRecommendedForPrinter: false,
        isRecommendedForScale: false,
      );
    }

    // 6. Audio Devices: Earbuds, Headphones & Neckbands (Mivi, Pods, Buds, Airdopes, Rockerz, TWS, Boult)
    if (name.contains('pods') ||
        name.contains('buds') ||
        name.contains('mivi') ||
        name.contains('airdopes') ||
        name.contains('airpod') ||
        name.contains('head') ||
        name.contains('ear') ||
        name.contains('rockerz') ||
        name.contains('bass') ||
        name.contains('audio') ||
        name.contains('neckband') ||
        name.contains('bullets') ||
        name.contains('wireless') ||
        name.contains('tws') ||
        name.contains('boult') ||
        name.contains('ptron') ||
        name.contains('hammer') ||
        name.contains('truke') ||
        name.contains('sony') ||
        name.contains('boat') ||
        name.contains('noise') ||
        name.contains('bluetooth music') ||
        name.contains('media')) {
      return const BluetoothDeviceClassification(
        type: BluetoothDeviceType.audio,
        label: 'ईयरबड्स / हेडफ़ोन (Headset)',
        badgeText: '🎧 ईयरबड्स',
        icon: Icons.headphones_rounded,
        primaryColor: Color(0xFF64748B),
        backgroundColor: Color(0xFFF1F5F9),
        isRecommendedForPrinter: false,
        isRecommendedForScale: false,
      );
    }

    // 7. Car Bluetooth / Audio Systems
    if (name.contains('car') ||
        name.contains('auto') ||
        name.contains('honda') ||
        name.contains('hyundai') ||
        name.contains('suzuki') ||
        name.contains('tata') ||
        name.contains('mahindra') ||
        name.contains('toyota') ||
        name.contains('handsfree') ||
        name.contains('obd')) {
      return const BluetoothDeviceClassification(
        type: BluetoothDeviceType.car,
        label: 'कार ऑडियो (Car BT)',
        badgeText: '🚗 कार',
        icon: Icons.directions_car_rounded,
        primaryColor: Color(0xFFD97706),
        backgroundColor: Color(0xFFFEF3C7),
        isRecommendedForPrinter: false,
        isRecommendedForScale: false,
      );
    }

    // 8. Computers & Laptops
    if (name.contains('pc') ||
        name.contains('laptop') ||
        name.contains('desktop') ||
        name.contains('macbook') ||
        name.contains('imac') ||
        name.contains('mac mini') ||
        name.contains('windows') ||
        name.contains('computer') ||
        name.contains('dell') ||
        name.contains('inspiron') ||
        name.contains('latitude') ||
        name.contains('lenovo') ||
        name.contains('thinkpad') ||
        name.contains('ideapad') ||
        name.contains('asus') ||
        name.contains('zenbook') ||
        name.contains('vivobook') ||
        name.contains('acer') ||
        name.contains('aspire') ||
        name.contains('hp ') ||
        name.contains('hp-') ||
        name.contains('pavilion') ||
        name.contains('surface') ||
        name.contains('msi') ||
        name.contains('workstation') ||
        name.contains('linux')) {
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

    // 9. Smartphones & Tablets
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
        name.contains('poco') ||
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
