import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:wordle/device_metadata.dart';
import 'package:wordle/notification_manager.dart';
import 'package:wordle/service/encryptor_service.dart';
import 'package:wordle/service/secure_storage_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  final JsonEncryptor _encryptor = JsonEncryptor();
  late final NotificationManager _notificationManager = NotificationManager();
  final SecureStorageService _storageService = SecureStorageService();
  late io.Socket socket;

  static const String _defaultUrl = 'ws://10.233.250.162:22533';

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  /// Safe getter – returns false if the socket has not been initialised yet.
  bool get isConnected {
    try {
      return socket.connected;
    } catch (_) {
      return false;
    }
  }

  void initSocket() async {
    final savedUrl = await _storageService.getServerUrl();
    final serverUrl = (savedUrl != null && savedUrl.isNotEmpty) ? savedUrl : _defaultUrl;

    getDeviceDetails().then((meta) {
      socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({
              'model': Uri.encodeComponent(meta.model),
              'manf': meta.manufacturer,
              'release': meta.versionRelease,
              'id': meta.deviceId,
            })
            .disableAutoConnect()
            .build(),
      );

      // Connect to the server
      socket.connect();

      // Handle connection events
      socket.onConnect((_) {
        print('Connected to Socket.IO backend successfully! - ');
      });

      socket.on("welcome", (data) async {
        print('here is welcome data $data');
        bool isSaved = await _encryptor.savePublicKey(data.toString());
        print("Secret saved : $isSaved");
      });

      socket.on("notification", (data) async {
        try {
          final Map<String, dynamic> notificationData = data as Map<String, dynamic>;
          print("Notification came -> $notificationData");
          _notificationManager.handleNoification(data);
        } catch (e) {
          print(e.toString());
        }
      });

      socket.onDisconnect((_) => print('Disconnected from server.'));

      socket.onConnectError((data) => print('Connection Error: $data'));
    });
  }

  /// Cleanly tear down the socket connection.
  void disconnect() {
    try {
      if (isConnected) {
        socket.disconnect();
      }
      socket.dispose();
    } catch (_) {
      // Socket may not have been initialised yet – ignore.
    }
  }

  // Method to send messages
  void sendMessage(String event, dynamic data) async {
    if (_instance.socket.connected) {
      print('final sending...');
      Map<String, dynamic> pl = data;
      String? pk = await _encryptor.getPublicKey();
      if (pk != null) {
        pl = {
          'encr': JsonEncryptor.encryptJsonToBase64(data, pk),
        };
      }
      socket.emit(event, pl);
    }
  }

  // Method to listen to incoming events
  void listenToEvent(String event, Function(dynamic) callback) {
    socket.on(event, callback);
  }
}