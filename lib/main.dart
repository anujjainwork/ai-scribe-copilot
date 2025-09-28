import 'package:drlogger/features/patient/model/patient_model.dart';
import 'package:drlogger/features/recorder/record_view.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RecorderApp());
}

class RecorderApp extends StatelessWidget {
  const RecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RecordView(
        patient: PatientModel(
          patientId: 'sudifhsdf',
          patientName: 'Anuj Jain',
          pronouns: 'he/him',
          email: 'jainanuj.work@gmail.com',
          age: 21,
        ),
      ),
    );
  }
}
