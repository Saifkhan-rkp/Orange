import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

/// A service class to handle microphone audio recording for a specified duration.
class AudioRecorderService {
  static final AudioRecorderService _instance = AudioRecorderService._internal();
  factory AudioRecorderService() => _instance;
  AudioRecorderService._internal();

  final AudioRecorder _record = AudioRecorder();
  String? _currentRecordingPath;
  Timer? _timer;

  /// Records audio from microphone for the given number of seconds.
  ///
  /// Returns the path to the saved audio file on success, or null on failure.
  Future<String?> recordForSeconds({
    required int seconds,
    String? customFileName,
  }) async {
    if (seconds <= 0) {
      debugPrint('Duration must be greater than 0');
      return null;
    }

    // Request permission
    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      debugPrint('Microphone permission denied');
      return null;
    }

    try {
      // Get temporary directory for recording
      final directory = await getTemporaryDirectory();
      final fileName = customFileName ?? 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final currentRecordingPath = '${directory.path}/$fileName';

      // Start recording
      await _record.start(RecordConfig( encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100), path: currentRecordingPath
      );

      debugPrint('Recording started for $seconds seconds at path $fileName');

      // Set timer to stop recording
      _timer?.cancel();
      _timer = Timer(Duration(seconds: seconds), () async {
        await stopRecording();
      });

      // Wait for the recording to complete
      await Future.delayed(Duration(seconds: seconds));
      
      return currentRecordingPath;
    } catch (e) {
      debugPrint('Error during recording: $e');
      await stopRecording();
      return null;
    }
  }

  /// Stops the current recording manually.
  Future<void> stopRecording() async {
    _timer?.cancel();
    _timer = null;

    if (await _record.isRecording()) {
      try {
        await _record.stop();
        debugPrint('Recording stopped. File saved at: $_currentRecordingPath');
      } catch (e) {
        debugPrint('Error stopping recording: $e');
      }
    }
  }

  /// Checks if currently recording
  Future<bool> isRecording() async {
    return await _record.isRecording();
  }

  /// Requests microphone permission
  Future<bool> _requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Dispose resources
  void dispose() {
    _timer?.cancel();
    _record.dispose();
  }
}