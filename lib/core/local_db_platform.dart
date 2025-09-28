import 'package:flutter/services.dart';

class LocalDbPlatform {
  static const MethodChannel _method = MethodChannel('drlogger/localdb');

  // Session operations
  static Future<void> insertSession(Map<String, dynamic> session) async {
    await _method.invokeMethod('insertSession', session);
  }

  static Future<List<Map<String, dynamic>>> getSessions() async {
    final result = await _method.invokeMethod<List>('getSessions');
    return (result ?? []).cast<Map<String, dynamic>>();
  }

  // AudioChunk operations
  static Future<void> insertChunk(Map<String, dynamic> chunk) async {
    await _method.invokeMethod('insertChunk', chunk);
  }

  static Future<List<Map<String, dynamic>>> getChunksBySession(String sessionId) async {
    final result = await _method.invokeMethod<List>(
      'getChunksBySession',
      {'sessionId': sessionId},
    );
    return (result ?? []).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getUploadedChunksBySession(String sessionId) async {
    final result = await _method.invokeMethod<List>(
      'getUploadedChunksBySession',
      {'sessionId': sessionId},
    );
    return (result ?? []).cast<Map<String, dynamic>>();
  }
}