class StartRecordingRequest {
  final String sessionId;
  final int chunkSizeMs;
  final String patientId;
  const StartRecordingRequest({required this.sessionId, required this.chunkSizeMs, required this.patientId});

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'chunkSizeMs': chunkSizeMs,
    'patientId' : patientId
  };

  factory StartRecordingRequest.fromMap(Map<String, dynamic> map) =>
      StartRecordingRequest(
        sessionId: map['sessionId'],
        chunkSizeMs: map['chunkSizeMs'],
        patientId: map['patientId']
      );
}

class StopRecordingRequest {
  final String sessionId;
  const StopRecordingRequest({required this.sessionId});

  Map<String, dynamic> toMap() => {'sessionId': sessionId};
}


class AudioChunkEvent {
  final String sessionId;
  final String audioId;
  final int chunkNumber;
  final String filePath; // saved in cache dir
  final int timestampMs; // relative to session start
  final double amplitude; // peak amplitude for waveform
  final bool lastChunk;

  const AudioChunkEvent({
    required this.sessionId,
    required this.audioId,
    required this.chunkNumber,
    required this.filePath,
    required this.timestampMs,
    required this.amplitude,
    required this.lastChunk,
  });

  factory AudioChunkEvent.fromMap(Map<String, dynamic> map) => AudioChunkEvent(
        sessionId: map['sessionId'],
        audioId: map['audioId'],
        chunkNumber: map['chunkNumber'],
        filePath: map['filePath'],
        timestampMs: map['timestampMs'],
        amplitude: (map['amplitude'] as num).toDouble(),
        lastChunk: map['lastChunk'] ?? false,
      );
}

class RecordingStatusEvent {
  final String sessionId;
  final String status; // "started", "paused", "resumed", "stopped", "error"
  final String? errorMessage;

  const RecordingStatusEvent({
    required this.sessionId,
    required this.status,
    this.errorMessage,
  });

  factory RecordingStatusEvent.fromMap(Map<String, dynamic> map) =>
      RecordingStatusEvent(
        sessionId: map['sessionId'],
        status: map['status'],
        errorMessage: map['errorMessage'],
      );
}

class TranscriptionEvent {
  final String sessionId;
  final int chunkNumber;
  final String partialText;
  final bool isFinal;

  const TranscriptionEvent({
    required this.sessionId,
    required this.chunkNumber,
    required this.partialText,
    required this.isFinal,
  });

  factory TranscriptionEvent.fromMap(Map<String, dynamic> map) =>
      TranscriptionEvent(
        sessionId: map['sessionId'],
        chunkNumber: map['chunkNumber'],
        partialText: map['partialText'],
        isFinal: map['isFinal'] ?? false,
      );
}