import 'package:drlogger/data/models/recording_model.dart';
import 'package:flutter/services.dart';

class AudioRecorderPlatform {
  static const MethodChannel _method = MethodChannel('drlogger/recorder');
  static const EventChannel _events = EventChannel('drlogger/recorder_events');

  /// Listen to events from native
  static Stream<dynamic> get events =>
      _events.receiveBroadcastStream().map((event) {
        final map = Map<String, dynamic>.from(event);
        switch (map['type']) {
          case 'chunk':
            return AudioChunkEvent.fromMap(map);
          case 'status':
            return RecordingStatusEvent.fromMap(map);
          default:
            return map;
        }
      });

  /// Control methods
  static Future<void> startRecording(StartRecordingRequest request) {
    return _method.invokeMethod('startRecording', request.toMap());
  }

  static Future<void> stopRecording(StopRecordingRequest request) {
    return _method.invokeMethod('stopRecording', request.toMap());
  }

  static Future<void> pauseRecording(String sessionId) {
    return _method.invokeMethod('pauseRecording', {'session_id': sessionId});
  }

  static Future<void> resumeRecording(String sessionId) {
    return _method.invokeMethod('resumeRecording', {'session_id': sessionId});
  }
}


class TranscriptionPlatform {
  static const EventChannel _events =
      EventChannel('drlogger/transcription_events');

  /// Stream of transcription events from native
  static Stream<TranscriptionEvent> get events =>
      _events.receiveBroadcastStream().map((event) {
        final map = Map<String, dynamic>.from(event);
        return TranscriptionEvent.fromMap(map);
      });
}
