import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactPickerResult {
  final String name;
  final String phone;
  final bool permissionDenied;
  final String? errorMessage;

  const ContactPickerResult({
    required this.name,
    required this.phone,
    this.permissionDenied = false,
    this.errorMessage,
  });

  bool get hasData => name.isNotEmpty || phone.isNotEmpty;
}

class ContactService {
  /// Prompts the user to pick a contact from their device address book.
  /// Automatically checks and requests read permission if needed.
  static Future<ContactPickerResult?> pickContact() async {
    try {
      bool hasPermission = await FlutterContacts.permissions.has(PermissionType.read);
      if (!hasPermission) {
        final status = await FlutterContacts.permissions.request(PermissionType.read);
        hasPermission = (status == PermissionStatus.granted || status == PermissionStatus.limited);
      }

      if (!hasPermission) {
        debugPrint('[ContactService] Contact read permission not granted.');
        return const ContactPickerResult(
          name: '',
          phone: '',
          permissionDenied: true,
          errorMessage: 'Permission not granted',
        );
      }

      Contact? contact;
      try {
        contact = await FlutterContacts.native.showPicker(
          properties: {ContactProperty.phone, ContactProperty.name},
        );
      } catch (pickerErr) {
        debugPrint('[ContactService] showPicker with properties failed: $pickerErr, fallback to default picker');
        try {
          contact = await FlutterContacts.native.showPicker();
        } catch (e2) {
          debugPrint('[ContactService] default showPicker failed: $e2');
          return ContactPickerResult(
            name: '',
            phone: '',
            errorMessage: e2.toString(),
          );
        }
      }

      if (contact == null) {
        // User closed the picker without selecting a contact
        return null;
      }

      String name = (contact.displayName ?? '').trim();
      final n = contact.name;
      if (name.isEmpty && n != null) {
        name = '${n.first ?? ''} ${n.last ?? ''}'.trim();
      }

      String phone = '';
      if (contact.phones.isNotEmpty) {
        phone = cleanPhoneNumber(contact.phones.first.number);
      }

      // If phone is still empty and we have contact id, query full contact by ID
      if (phone.isEmpty && contact.id != null) {
        try {
          final full = await FlutterContacts.get(
            contact.id!,
            properties: {ContactProperty.phone, ContactProperty.name},
          );
          if (full != null) {
            if (full.phones.isNotEmpty) {
              phone = cleanPhoneNumber(full.phones.first.number);
            }
            if (name.isEmpty) {
              name = (full.displayName ?? '').trim();
            }
          }
        } catch (e) {
          debugPrint('[ContactService] Fallback get contact error: $e');
        }
      }

      return ContactPickerResult(name: name, phone: phone);
    } catch (e) {
      debugPrint('[ContactService] Error picking contact: $e');
      return ContactPickerResult(
        name: '',
        phone: '',
        errorMessage: e.toString(),
      );
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
