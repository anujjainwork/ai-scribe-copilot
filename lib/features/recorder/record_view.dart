import 'dart:io';
import 'dart:math';
import 'package:drlogger/core/platform_setup.dart';
import 'package:drlogger/data/models/recording_model.dart';
import 'package:drlogger/features/patient/model/patient_model.dart';
import 'package:drlogger/features/uploaded/view/uploaded_chunks_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:random_avatar/random_avatar.dart';

class RecordView extends StatefulWidget {
  final PatientModel patient;
  const RecordView({super.key, required this.patient});

  @override
  State<RecordView> createState() => _RecordViewState();
}

class _RecordViewState extends State<RecordView>
    with SingleTickerProviderStateMixin {
  String _transcription = "";
  final StringBuffer _transcriptionBuffer = StringBuffer();
  final ScrollController _scrollController = ScrollController();

  bool _isRecording = false;
  bool _isPaused = false;

  final int _maxBars = 60;
  final List<double> _displayedAmplitudes = [];
  double _targetAmplitude = 0;
  late final Ticker _ticker;
  final Random _random = Random();

  Stream<dynamic>? _eventsStream;
  Stream<TranscriptionEvent>? _transcriptionStream;

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < _maxBars; i++) {
      _displayedAmplitudes.add(0);
    }

    _eventsStream = AudioRecorderPlatform.events;
    _eventsStream?.listen((event) {
      if (event is AudioChunkEvent) {
        final amp = event.amplitude.toDouble();

        double normalized = amp;
        if (normalized > 1.0) {
          normalized = (amp / 32768.0).clamp(0.0, 1.0);
        }

        _targetAmplitude = (normalized * 0.8).clamp(0.0, 1.0);
      } else if (event is RecordingStatusEvent) {
        if (event.status == 'paused' || event.status == 'stopped') {
          setState(() {
            _isPaused = true;
            _isRecording = false;
          });
        } else {
          setState(() {
            _isPaused = false;
            _isRecording = true;
          });
        }
      }
    });

    _transcriptionStream = TranscriptionPlatform.events;
    _transcriptionStream?.listen((event) {
      setState(() {
        _transcriptionBuffer.write("${event.partialText} ");
        _transcription = _transcriptionBuffer.toString();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });

    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!_isRecording || _isPaused) return;

    setState(() {
      for (int i = 0; i < _displayedAmplitudes.length - 1; i++) {
        _displayedAmplitudes[i] = _displayedAmplitudes[i + 1];
      }

      final current = _displayedAmplitudes.last;
      final diff = _targetAmplitude - current;

      final step = diff * 0.15;

      final randomSpike = (_random.nextDouble() - 0.5) * 0.01;

      _displayedAmplitudes[_displayedAmplitudes.length -
          1] = (current + step + randomSpike).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await ensureMicPermission() &&
        (Platform.isIOS || await ensurePhonePermission())) {
      await AudioRecorderPlatform.startRecording(
        StartRecordingRequest(
          sessionId: "test_session",
          chunkSizeMs: 15000,
          patientId: widget.patient.patientId,
        ),
      );
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _transcriptionBuffer.clear();
        _transcription = "";
        for (int i = 0; i < _maxBars; i++) {
          _displayedAmplitudes[i] = 0;
        }
      });
    }
  }

  Future<void> _pauseRecording() async {
    await AudioRecorderPlatform.pauseRecording("test_session");
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    await AudioRecorderPlatform.resumeRecording("test_session");
    setState(() => _isPaused = false);
  }

  Future<void> _stopRecording() async {
    await AudioRecorderPlatform.stopRecording(
      StopRecordingRequest(sessionId: "test_session"),
    );
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
  }

  Future<bool> ensureMicPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> ensurePhonePermission() async {
    var status = await Permission.phone.status;
    if (!status.isGranted) status = await Permission.phone.request();
    return status.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0D5C73),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(190),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF0D5C73),
          elevation: 0,
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return UploadedChunksScreen();
                          },
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        Text(
                          'Tap to view uploaded audio chunks public urls',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: Colors.white.withAlpha(50),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RandomAvatar('Anuj', height: 70, width: 70),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.patient.patientName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    widget.patient.pronouns ??
                                        'Unknown pronouns',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    width: 1,
                                    height: 12,
                                    color: Colors.white70,
                                  ),
                                  Text(
                                    widget.patient.age?.toString() ??
                                        'Unknown age',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.patient.email,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Record your observations",
              style: TextStyle(
                fontSize: 24,
                fontFamily: 'MonaSans-Black',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Text(
                    _transcription.isEmpty
                        ? "Transcription will appear here..."
                        : _transcription,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 80,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(
                painter: WaveformPainter(_displayedAmplitudes),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.mic, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: _isRecording ? null : _startRecording,
                ),
                IconButton(
                  icon: const Icon(Icons.pause, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed:
                      (_isRecording && !_isPaused) ? _pauseRecording : null,
                ),
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed:
                      (_isRecording && _isPaused) ? _resumeRecording : null,
                ),
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: _isRecording ? _stopRecording : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  WaveformPainter(this.amplitudes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.teal
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    final midY = size.height / 2;
    final barWidth =
        size.width / (amplitudes.isNotEmpty ? amplitudes.length : 1);

    for (int i = 0; i < amplitudes.length; i++) {
      final barHeight = (amplitudes[i] * midY).clamp(1, midY);
      final x = i * barWidth;
      canvas.drawLine(
        Offset(x, midY - barHeight),
        Offset(x, midY + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}
