import 'package:drlogger/core/local_db_platform.dart';
import 'package:drlogger/data/models/audio_chunk.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UploadedChunksScreen extends StatefulWidget {
  const UploadedChunksScreen({super.key});

  @override
  State<UploadedChunksScreen> createState() => _UploadedChunksScreenState();
}

class _UploadedChunksScreenState extends State<UploadedChunksScreen> {
  List<AudioChunk> uploadedChunks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUploadedChunks();
  }

  Future<void> fetchUploadedChunks() async {
    setState(() => isLoading = true);
    try {
      final chunkMaps = await LocalDbPlatform.getUploadedChunksBySession(
        'test_session',
      );

      final chunks =
          chunkMaps.map((map) {
            return AudioChunk(
              audioId: map['audioId'],
              sessionId: map['sessionId'],
              chunkNumber: map['chunkNumber'] ?? 0,
              filePath: map['filePath'] ?? '',
              durationMs: map['durationMs'] ?? 0,
              amplitude: map['amplitude']?.toDouble(),
              status: map['status'] ?? '',
              createdAt:
                  DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
              gcsPath: map['gcsPath'],
              publicUrl: map['publicUrl'] ?? '',
            );
          }).toList();

      setState(() {
        uploadedChunks = chunks;
      });
    } catch (e) {
      debugPrint('Failed to fetch uploaded chunks: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> openChunkUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uploaded Chunks')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : uploadedChunks.isEmpty
              ? const Center(child: Text('No uploaded chunks found.'))
              : ListView.builder(
                itemCount: uploadedChunks.length,
                itemBuilder: (context, index) {
                  final chunk = uploadedChunks[index];

                  return ListTile(
                    title: Text('Chunk #${chunk.chunkNumber}'),
                    subtitle: Text(chunk.filePath),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => openChunkUrl(chunk.publicUrl ?? ''),
                  );
                },
              ),
    );
  }
}
