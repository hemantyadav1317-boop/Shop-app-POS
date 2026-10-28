import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactPickerResult {
  final String name;
  final String phone;

  const ContactPickerResult({required this.name, required this.phone});
}

class ContactService {
  /// Prompts the user to pick a contact from their device address book.
  /// Automatically requests read permission if needed.
  static Future<ContactPickerResult?> pickContact() async {
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
        debugPrint('[ContactService] Contact read permission not granted ($status).');
        return null;
      }

      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.phone, ContactProperty.name},
      );
      if (contact == null) return null;

      String name = (contact.displayName ?? '').trim();
      final n = contact.name;
      if (name.isEmpty && n != null) {
        name = '${n.first ?? ''} ${n.last ?? ''}'.trim();
      }

      String phone = '';
      if (contact.phones.isNotEmpty) {
        phone = cleanPhoneNumber(contact.phones.first.number);
      } else {
        // Fallback: If properties weren't returned by picker, fetch directly by ID
        try {
          final id = contact.id;
          if (id != null) {
            final full = await FlutterContacts.get(
              id,
              properties: {ContactProperty.phone, ContactProperty.name},
            );
            if (full != null && full.phones.isNotEmpty) {
              phone = cleanPhoneNumber(full.phones.first.number);
              if (name.isEmpty) {
                name = (full.displayName ?? '').trim();
              }
            }
          }
        } catch (_) {}
      }

      return ContactPickerResult(name: name, phone: phone);
    } catch (e) {
      debugPrint('[ContactService] Error picking contact: $e');
      return null;
    }
  }

  /// Sanitizes phone numbers by stripping country codes (+91), spaces, hyphens,
  /// and leading zeros, keeping a clean standard 10-digit mobile number when applicable.
  static String cleanPhoneNumber(String raw) {
    if (raw.isEmpty) return '';
    String digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }
}
