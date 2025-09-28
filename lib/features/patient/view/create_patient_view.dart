import 'package:drlogger/components/custom_button.dart';
import 'package:drlogger/components/custom_text_field.dart';
import 'package:drlogger/features/patient/model/patient_model.dart';
import 'package:drlogger/features/recorder/record_view.dart';
import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';

const String newPatientCardTag = 'newPatientCard';

class CreatePatientView extends StatefulWidget {
  const CreatePatientView({super.key});

  @override
  State<CreatePatientView> createState() => _CreatePatientViewState();
}

class _CreatePatientViewState extends State<CreatePatientView> {
  final TextEditingController uidController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: newPatientCardTag,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xff074A65),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create',
              style: const TextStyle(
                fontFamily: 'MonaSans-Black',
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 40),
            Center(child: RandomAvatar('CREATE', height: 120, width: 120)),
            SizedBox(height: 40),
            CustomTextField(
              controller: nameController,
              title: 'Name',
              hintText: 'Enter name',
            ),
            SizedBox(height: 20),
            CustomTextField(
              controller: uidController,
              title: 'userId',
              hintText: 'Enter user id',
            ),
            SizedBox(height: 40),
            Center(
              child: CustomButton(
                title: 'CREATE',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return RecordView(
                          patient: PatientModel(
                            patientId: 'zSDfsdf',
                            patientName: 'Anuj Jain',
                            email: 'iamanujjain01@gmail.com',
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
