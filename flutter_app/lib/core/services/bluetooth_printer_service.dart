import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import '../../data/models/sale.dart';
import '../../data/models/shop.dart';
import 'ai_quote_service.dart';
import 'printer_settings_service.dart';

class BluetoothPrinterService {
  static const String _prefMacKey = 'saved_bt_printer_mac';
  static const String _prefNameKey = 'saved_bt_printer_name';

  static Future<bool> isPermissionGranted() async {
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (e) {
      debugPrint("Error checking bt permission: $e");
      return false;
    }
  }

  static Future<bool> isBluetoothEnabled() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      debugPrint("Error checking bluetooth: $e");
      return false;
    }
  }

  static Future<List<BluetoothInfo>> getPairedDevices() async {
    try {
      // Ensure Android Nearby Devices / Bluetooth permission is prompted
      await isPermissionGranted();
      final List<BluetoothInfo> list = await PrintBluetoothThermal.pairedBluetooths;
      return list;
    } catch (e) {
      debugPrint("Error getting paired devices: $e");
      return [];
    }
  }

  static Future<bool> isConnected() async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getSavedPrinterMac() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefMacKey);
  }

  static Future<String?> getSavedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefNameKey);
  }

  static Future<void> saveSelectedPrinter(String mac, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMacKey, mac);
    await prefs.setString(_prefNameKey, name);
  }

  static Future<void> forgetPrinter() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefMacKey);
    await prefs.remove(_prefNameKey);
  }

  static Future<bool> connectPrinter(String macAddress) async {
    try {
      final bool connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      return connected;
    } catch (e) {
      debugPrint("Error connecting to printer: $e");
      return false;
    }
  }

  /// Ensure connected to saved printer before printing
  static Future<bool> ensureConnected() async {
    final connected = await isConnected();
    if (connected) return true;

    final savedMac = await getSavedPrinterMac();
    if (savedMac == null || savedMac.isEmpty) return false;

    return await connectPrinter(savedMac);
  }

  /// Direct ESC/POS printing to Bluetooth Thermal Printer
  static Future<bool> printReceiptDirect({
    required Sale sale,
    required Shop shop,
    Uint8List? imageBytes,
  }) async {
    final ready = await ensureConnected();
    if (!ready) {
      return false;
    }

    try {
      final profile = await CapabilityProfile.load();
      final ps = PrinterSettingsService.instance;
      final is80mm = ps.paperSize == '80mm' || shop.printPaperSize == '80mm';
      final paperSize = is80mm ? PaperSize.mm80 : PaperSize.mm58;
      final generator = Generator(paperSize, profile);

      List<int> bytes = [];
      bytes += generator.reset();

      if (imageBytes != null && imageBytes.isNotEmpty) {
        // High-fidelity image mode (Supports Hindi, Barcode, Logo, Exact Scaled Fonts)
        img.Image? decoded = img.decodeImage(imageBytes);
        if (decoded != null) {
          final targetWidth = is80mm ? 576 : 384;
          img.Image resized = img.copyResize(decoded, width: targetWidth);
          // Solid white background to prevent transparent artifacts on thermal printers
          img.Image whiteBg = img.Image(width: resized.width, height: resized.height);
          img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
          img.compositeImage(whiteBg, resized);
          bytes += generator.imageRaster(whiteBg, align: PosAlign.center);
        }
      } else {
        // Text mode fallback respecting toggles & scaling
        if (ps.showShopName) {
          bytes += generator.text(
            shop.name,
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              bold: true,
            ),
          );
        }
        if (ps.showAddress && shop.address != null && shop.address!.isNotEmpty) {
          bytes += generator.text(shop.address!, styles: const PosStyles(align: PosAlign.center));
        }
        if (ps.showPhone && shop.phone != null && shop.phone!.isNotEmpty) {
          bytes += generator.text('Tel: ${shop.phone!}', styles: const PosStyles(align: PosAlign.center));
        }
        if (ps.showGstin && shop.gstin != null && shop.gstin!.isNotEmpty) {
          bytes += generator.text('GSTIN: ${shop.gstin!}', styles: const PosStyles(align: PosAlign.center));
        }
        bytes += generator.hr();

        bytes += generator.row([
          PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
          PosColumn(text: 'Qty', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
          PosColumn(text: 'Price', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
        bytes += generator.hr();

        for (final item in sale.items) {
          bytes += generator.row([
            PosColumn(text: item.name, width: 6),
            PosColumn(text: '${item.qty}', width: 2, styles: const PosStyles(align: PosAlign.right)),
            PosColumn(text: '₹${item.price * item.qty}', width: 4, styles: const PosStyles(align: PosAlign.right)),
          ]);
        }
        bytes += generator.hr();

        bytes += generator.row([
          PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
          PosColumn(text: '₹${sale.total.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
        ]);
        bytes += generator.hr();

        if (ps.showQuote) {
          final quote = await AiQuoteService.getUniqueQuoteForBill();
          bytes += generator.text(quote.line1, styles: const PosStyles(align: PosAlign.center, bold: true));
          bytes += generator.text(quote.line2, styles: const PosStyles(align: PosAlign.center));
        }

        if (ps.showFooter) {
          bytes += generator.text(shop.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏', styles: const PosStyles(align: PosAlign.center));
        }
      }

      bytes += generator.feed(2);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint("Error in printReceiptDirect: $e");
      return false;
    }
  }

  /// Print a quick test receipt to verify printer
  static Future<bool> printTestReceipt(Shop shop) async {
    final ready = await ensureConnected();
    if (!ready) return false;

    try {
      final profile = await CapabilityProfile.load();
      final is80mm = shop.printPaperSize == '80mm';
      final generator = Generator(is80mm ? PaperSize.mm80 : PaperSize.mm58, profile);

      List<int> bytes = [];
      bytes += generator.reset();
      bytes += generator.text(
        shop.name,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
      );
      bytes += generator.text('Bluetooth Printer Test OK!', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Shop POS System', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.text('Paper: ${shop.printPaperSize}', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Status: Connected & Working', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint("Test print error: $e");
      return false;
    }
  }
}
