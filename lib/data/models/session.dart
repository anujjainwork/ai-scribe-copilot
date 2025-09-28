class Session {
  final String sessionId;
  final String serverSessionId;
  final String patientId;
  final String status;
  final DateTime startTime;
  final DateTime? endTime;

  Session({
    required this.sessionId,
    required this.serverSessionId,
    required this.patientId,
    required this.status,
    required this.startTime,
    required this.endTime,
  });
}
