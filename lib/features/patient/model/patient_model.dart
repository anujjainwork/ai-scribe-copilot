class PatientModel {
  final String patientId;
  final String patientName;
  final String email;
  final int? age;
  final String? pronouns;

  PatientModel({
    required this.patientId,
    required this.patientName,
    required this.email,
    this.age,
    this.pronouns,
  });

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'email': email,
      'age': age,
      'pronouns': pronouns,
    };
  }

  factory PatientModel.fromMap(Map<String, dynamic> map) {
    return PatientModel(
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      email: map['email'] ?? '',
      age: map['age'] != null ? map['age'] as int : null,
      pronouns: map['pronouns'],
    );
  }
}
