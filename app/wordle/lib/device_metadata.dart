import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceMetadata {
  final String model;
  final String manufacturer;
  final String versionRelease;
  final String deviceId;

  DeviceMetadata({
    required this.model,
    required this.manufacturer,
    required this.versionRelease,
    required this.deviceId,
  });
}

Future<DeviceMetadata> getDeviceDetails() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    
    return DeviceMetadata(
      model: androidInfo.model,                  // e.g., "Pixel 7 Pro" or "SM-G998B"
      manufacturer: androidInfo.manufacturer,    // e.g., "Google" or "Samsung"
      versionRelease: androidInfo.version.release, // e.g., "14" or "13"
      deviceId: androidInfo.id,                  // Hardware/Build ID string
    );
    
  } else if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    
    return DeviceMetadata(
      model: iosInfo.model,                             // e.g., "iPhone"
      manufacturer: "Apple",                             // iOS doesn't have a specific manufacturer property
      versionRelease: iosInfo.systemVersion,            // e.g., "17.4"
      deviceId: iosInfo.identifierForVendor ?? "unknown", // Hardware UUID assigned by iOS to this vendor
    );
  }

  throw UnsupportedError("Platform not supported");
}