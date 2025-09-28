import 'package:drlogger/features/patient/view/create_patient_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _recordNewTapped = false;
  bool _createNewUser = false;
  double? screenWidth;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE d MMMM y').format(now).toUpperCase();
    screenWidth = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  _recordNewTapped ? 'Record New' : 'Hi Doctor',
                  style: const TextStyle(
                    fontFamily: 'MonaSans-Black',
                    color: Colors.black,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _recordNewTapped
                      ? 'ARE YOU VISITING A NEW PATIENT?'
                      : formattedDate,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                _createNewUser ? CreatePatientView():
                _recordNewTapped
                    ? participantsActionButtons()
                    : actionButtonCards(),
                const SizedBox(height: 30),
                Center(
                  child:
                      _recordNewTapped
                          ? GestureDetector(
                            onTap: () {
                              setState(() {
                                _recordNewTapped = false;
                                _createNewUser = false;
                              });
                            },
                            child: Text(
                              'BACK TO HOME SCREEN',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                decorationColor: Colors.grey,
                                decoration: TextDecoration.combine([TextDecoration.underline]),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          : SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget actionButtonCards() {
    return SizedBox(
      width: screenWidth,
      child: Row(
        children: [
          Expanded(
            child: actionButtonCard(
              title: 'Record New',
              subtitle: 'add transcriptions',
              textColor: Colors.white,
              icon: Icons.add,
              onTap: () {
                setState(() {
                  _recordNewTapped = true;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: actionButtonCard(
              color: Colors.white,
              textColor: Colors.black,
              hasBorder: true,
              icon: Icons.search,
              title: 'Browse patients',
              subtitle: 'view old sessions',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget participantsActionButtons() {
    return SizedBox(
      width: screenWidth,
      child: Row(
        children: [
          Expanded(
            child: actionButtonCard(
              title: 'New Patient',
              subtitle: 'add new patient',
              textColor: Colors.white,
              icon: Icons.add,
              onTap: () {
                setState(() {
                  _createNewUser = true;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: actionButtonCard(
              color: Colors.white,
              textColor: Colors.black,
              hasBorder: true,
              icon: Icons.repeat_rounded,
              title: 'Old patient',
              subtitle: 'select old patient',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget actionButtonCard({
    Color? color,
    Color? textColor,
    bool hasBorder = false,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: newPatientCardTag,
        child: Container(
          height: 250,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color ?? const Color(0xff074A65),
            borderRadius: BorderRadius.circular(12),
            border:
                hasBorder ? Border.all(width: 0.5, color: Colors.black54) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 44),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'MonaSans-Black',
                  color: textColor ?? Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
