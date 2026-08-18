import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:wordle/socketio_service.dart';

// Universal streams for the background process
StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
Timer? _screenOffTimer;

/// Called once from main() – configures & starts the foreground service.
/// startService() is a no-op when the service is already running → single instance.
Future<void> initializeService() async {
  try {
    
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'wordle_sync_channel',
        initialNotificationTitle: 'Sync Service Active',
        initialNotificationContent: 'Waiting for Service Notifications...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // No-op if already running → guarantees a single service (and therefore a single socket).
    await service.startService();
  } catch (e) {
    print("Error in foreground service $e");
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "Sync Service Active",
      content: "Waiting for Service Notifications...",
    );

    // 1. Listen for Native OS Events (Screen On / Screen Off)
    service.on('action').listen((event) {
      String? nativeAction = event?['action'];

      if (nativeAction == "android.intent.action.SCREEN_OFF") {
        _startScreenOffTimer(service);
      } else if (nativeAction == "android.intent.action.SCREEN_ON") {
        _cancelScreenOffTimer();
      }
    });
  }

  // 2. Monitor Internet Connectivity
  _networkSubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    bool hasInternet = results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi);

    // EXIT CONDITION 1: Turn off instantly if internet drops
    if (!hasInternet) {
      print("[Background] Internet disconnected. Shutting down instantly.");
      _shutDownService(service);
    }
  });

  // Execute your actual processing work here
  _waitForNotification();
}

void _startScreenOffTimer(ServiceInstance service) {
  print("[Background] Screen went off. Starting 5-minute countdown...");
  _screenOffTimer?.cancel();

  // EXIT CONDITION 2: Kill service after 5 minutes of screen off
  _screenOffTimer = Timer(const Duration(minutes: 5), () {
    print("[Background] Screen was off for 5 minutes. Shutting down.");
    _shutDownService(service);
  });
}

void _cancelScreenOffTimer() {
  if (_screenOffTimer != null && _screenOffTimer!.isActive) {
    print("[Background] Screen turned back on. Cancelling countdown.");
    _screenOffTimer?.cancel();
  }
}

void _shutDownService(ServiceInstance service) {
  // Cleanly tear down the socket before stopping the service.
  SocketService().disconnect();

  _networkSubscription?.cancel();
  _screenOffTimer?.cancel();
  service.stopSelf();
}

void _waitForNotification() {
  // Open (or re-use) the singleton Socket.IO connection inside the background isolate.
  // SocketService is a Dart singleton, so only one socket exists even if this is called more than once.
  SocketService().initSocket();
}