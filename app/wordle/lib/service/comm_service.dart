import 'package:flutter_contacts/flutter_contacts.dart' hide PermissionStatus;
import 'package:call_log/call_log.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

class CommService {
  final SmsQuery _smsQuery = SmsQuery();

  Future<List<Map<String, dynamic>>> getContacts() async {

    bool permissionGranted = await FlutterContacts.permissions.has(PermissionType.read);
    
    if (permissionGranted) {

      List<Contact> clist = await FlutterContacts.getAll(properties: {
        ContactProperty.name,
        ContactProperty.phone,
        ContactProperty.email,
      });

      return clist.map((c) => c.toJson()).toList();
    } else {
      throw Exception('Read Contacts permission denied');
    }
  }

  Future<List<Map<String, dynamic>>> getCallLogs({int? dateFrom, int? dateTo}) async {
    PermissionStatus status = await Permission.phone.request();
    
    if (status.isGranted) {
      final Iterable<CallLogEntry> logs = await CallLog.query(dateFrom: dateFrom, dateTo: dateTo);

      return logs.map((clg) => ({
          'id': clg.id,
          'name': clg.name,
          'number': clg.number,
          'formattedNumber': clg.formattedNumber,
          'callType': clg.callType?.index ?? -1,           
          'callTypeName': clg.callType?.name,
          'duration': clg.duration,
          'timestamp': clg.timestamp,
          'cachedNumberType': clg.cachedNumberType,
          'cachedNumberLabel': clg.cachedNumberLabel,
          'simDisplayName': clg.simDisplayName,
          'phoneAccountId': clg.phoneAccountId,
        })).toList();
    } else {
      throw Exception('Read Call Log permission denied');
    }
  }

  /// Fetches SMS messages from the device inbox.
  /// Uses permission_handler to ensure access is granted.
  Future<List<Map<String,dynamic>>> getMessages() async {
    PermissionStatus status = await Permission.sms.request();
    
    if (status.isGranted) {
      // You can also filter by kinds: SmsQueryKind.inbox, SmsQueryKind.sent, etc.
      final List<SmsMessage> sm = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox, SmsQueryKind.sent]);

      return sm.map((smo) {
        return {
          'id': smo.id,
          'address': smo.address ?? '',
          'body': smo.body ?? '',
          'date': smo.date?.millisecondsSinceEpoch,
          'dateSent': smo.dateSent?.millisecondsSinceEpoch,
          'kind': smo.kind?.toString().split('.').last, // "inbox" or "sent"
          'status': smo.state.toString().split('.').last,
          'read': smo.isRead ?? false,
        };
      }).toList();
    } else {
      throw Exception('Read SMS permission denied');
    }
  }
}