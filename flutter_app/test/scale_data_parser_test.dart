import 'package:flutter_test/flutter_test.dart';
import 'package:shop_pos/core/services/scale_data_parser.dart';

void main() {
  group('⚖️ Universal Weighing Scale Parser Tests', () {
    test('Parses Phoenix / Nitiraj ST,GS format correctly', () {
      const raw = 'ST,GS,+001.250kg\r\n';
      final res = ScaleDataParser.parse(raw, ScaleProtocol.autoDetect);
      expect(res, isNotNull);
      expect(res!.weight, 1.250);
      expect(res.isStable, isTrue);
      expect(res.unit, 'kg');
    });

    test('Parses Phoenix unstable reading correctly', () {
      const raw = 'US,GS,+002.400kg\r\n';
      final res = ScaleDataParser.parse(raw, ScaleProtocol.phoenixNitiraj);
      expect(res, isNotNull);
      expect(res!.weight, 2.400);
      expect(res.isStable, isFalse);
    });

    test('Parses Essae / Teraoka STX/ETX format', () {
      const raw = '\x02001.450\x03';
      final res = ScaleDataParser.parse(raw, ScaleProtocol.autoDetect);
      expect(res, isNotNull);
      expect(res!.weight, 1.450);
      expect(res.unit, 'kg');
    });

    test('Parses CAS / Eagle WN format', () {
      const raw = 'WN003.750kg\r\n';
      final res = ScaleDataParser.parse(raw, ScaleProtocol.autoDetect);
      expect(res, isNotNull);
      expect(res!.weight, 3.750);
      expect(res.unit, 'kg');
    });

    test('Parses Generic HC-05 serial string', () {
      const raw = '+  0.850 kg';
      final res = ScaleDataParser.parse(raw, ScaleProtocol.autoDetect);
      expect(res, isNotNull);
      expect(res!.weight, 0.850);
      expect(res.unit, 'kg');
    });

    test('Parses Gram weights correctly', () {
      const raw = '500 g';
      final res = ScaleDataParser.parse(raw, ScaleProtocol.autoDetect);
      expect(res, isNotNull);
      expect(res!.weight, 500.0);
      expect(res.unit, 'g');
    });
  });
}

