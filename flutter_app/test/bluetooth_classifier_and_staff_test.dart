import 'package:flutter_test/flutter_test.dart';
import 'package:shop_pos/core/services/bluetooth_device_classifier.dart';

void main() {
  group('📶 Bluetooth Device Classifier Tests', () {
    test('Identifies Smartwatches correctly', () {
      final watches = [
        'ColorFit Pulse 2',
        'NoiseFit Halo',
        'Fire-Boltt Ninja Call Pro',
        'boAt Wave Call',
        'boAt Storm Pro',
        'Titan Talk Smartwatch',
        'Fastrack Reflex Play',
        'Amazfit GTR 4',
        'Galaxy Watch 6',
        'Apple Watch Ultra',
        'BeatXP Marv Raze',
        'Boult Drift Pro',
      ];

      for (final w in watches) {
        final c = BluetoothDeviceClassifier.classify(w, '00:11:22:33:44:55');
        expect(c.type, BluetoothDeviceType.watch, reason: 'Failed for: $w');
        expect(c.isRecommendedForPrinter, isFalse);
      }
    });

    test('Identifies Smart TVs and Media streamers correctly', () {
      final tvs = [
        'Mi TV 4A 43',
        'Samsung Smart TV',
        'Sony Bravia 4K',
        'OnePlus TV 55',
        'Vu TV Ultra 4K',
        'TCL SmartTV',
        'Fire TV Stick 4K',
        'Living Room AndroidTV',
      ];

      for (final tv in tvs) {
        final c = BluetoothDeviceClassifier.classify(tv, '00:11:22:33:44:55');
        expect(c.type, BluetoothDeviceType.tv, reason: 'Failed for: $tv');
        expect(c.isRecommendedForPrinter, isFalse);
      }
    });

    test('Identifies Computers and Laptops correctly', () {
      final pcs = [
        'Dell Inspiron 15',
        'HP Pavilion Gaming',
        'Lenovo ThinkPad X1',
        'MacBook Air M2',
        'Asus ZenBook 14',
        'Acer Aspire 5',
        'MSI Gaming PC',
      ];

      for (final pc in pcs) {
        final c = BluetoothDeviceClassifier.classify(pc, '00:11:22:33:44:55');
        expect(c.type, BluetoothDeviceType.computer, reason: 'Failed for: $pc');
        expect(c.isRecommendedForPrinter, isFalse);
      }
    });

    test('Identifies Speakers from user screenshot correctly', () {
      final speakers = [
        'ZEB-HOPE 2',
        'TG-113',
        'BT-VO9M',
        'THRILLER 1200',
        'Moco-BT',
        'boAt Stone 650',
        'JBL Flip 6',
      ];

      for (final spk in speakers) {
        final c = BluetoothDeviceClassifier.classify(spk, '00:11:22:33:44:55');
        expect(c.type, BluetoothDeviceType.audio, reason: 'Failed for: $spk');
        expect(c.badgeText.contains('🔊'), isTrue, reason: 'Speaker badge failed for: $spk');
        expect(c.isRecommendedForPrinter, isFalse);
      }
    });

    test('Identifies Earbuds and Headsets correctly', () {
      final earbuds = [
        'Mivi DuoPods F30',
        'boAt Airdopes 141',
        'Realme Buds Air',
        'OnePlus Bullets Wireless',
      ];

      for (final eb in earbuds) {
        final c = BluetoothDeviceClassifier.classify(eb, '00:11:22:33:44:55');
        expect(c.type, BluetoothDeviceType.audio, reason: 'Failed for: $eb');
        expect(c.badgeText.contains('🎧'), isTrue, reason: 'Earbuds badge failed for: $eb');
        expect(c.isRecommendedForPrinter, isFalse);
      }
    });

    test('Identifies Thermal Printers correctly', () {
      final printers = [
        'InnerPrinter',
        'POS-58',
        'RPP-02N',
        'Bluetooth Printer T80',
        'Epson TM-T88VI',
        'XP-58C',
      ];

      for (final p in printers) {
        final c = BluetoothDeviceClassifier.classify(p, '00:11:22:33:44:55');
        expect(c.type, BluetoothDeviceType.printer, reason: 'Failed for: $p');
        expect(c.isRecommendedForPrinter, isTrue);
      }
    });

    test('Identifies Weighing Scales correctly', () {
      final scales = [
        'BT-Scale',
        'Kaanta W01',
        'Essae Weighing Machine',
        'Eagle BT Scale',
        'Nitiraj Electronic Scale',
      ];

      for (final s in scales) {
        final c = BluetoothDeviceClassifier.classify(s, '00:11:22:33:44:55');
        expect(c.type, BluetoothDeviceType.scale, reason: 'Failed for: $s');
        expect(c.isRecommendedForScale, isTrue);
      }
    });
  });
}

