class AudioChunk {
  final String audioId;
  final String sessionId;
  final int chunkNumber;
  final String filePath;
  final int durationMs;
  final String status;
  final DateTime createdAt;
  final double? amplitude;
  final String? gcsPath;
  final String? publicUrl;

  AudioChunk({
    required this.audioId,
    required this.sessionId,
    required this.chunkNumber,
    required this.filePath,
    required this.amplitude,
    required this.durationMs,
    required this.status,
    required this.createdAt,
    required this.gcsPath,
    required this.publicUrl,
  });
}
