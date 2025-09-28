import 'package:drlogger/features/patient/model/patient_model.dart';
import 'package:flutter/material.dart';

class BrowsePatients extends StatefulWidget {
  const BrowsePatients({super.key});

  @override
  State<BrowsePatients> createState() => _BrowsePatientsState();
}

class _BrowsePatientsState extends State<BrowsePatients> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                'Browse patients',
                style: const TextStyle(
                  fontFamily: 'MonaSans-Black',
                  color: Colors.black,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
