import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DetailInformationScreen extends StatefulWidget {
  const DetailInformationScreen({super.key});

  @override
  State<DetailInformationScreen> createState() =>
      _DetailInformationScreenState();
}

class _DetailInformationScreenState extends State<DetailInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fatherController = TextEditingController();
  final _customStatusController = TextEditingController();
  final _disciplineController = TextEditingController(); // 👈 new
  final _cnicController = TextEditingController();
  // final _sectionController = TextEditingController();

  DateTime? _commencingDate;
  DateTime? _admissionDate;

  String? session;
  String? semester;
  String? status;
  String? faculty;
  String? department;
  String? degree; // 👈 new dropdown
  String? section; // 👈 new dropdown

  Map<String, dynamic>? existingData;
  bool _alreadyFilled = false;
  bool _loading = false;

  final sessions = ["Winter 2025-2026", "Spring 2026"];
  final semesters = ["Semester 1", "Semester 2", "Semester 3", "Semester 4","Semester 5","Semester 6","Semester 7","Semester 8","Semester 9","Semester 10",
    "Semester 11",
    "Semester 12",];

  final statuses = [
    "Regular Student",
    "Govt. Employee (on leave)",
    "University Employee (Academic/ Administration)",
    "Employee of other statutory organization (on leave)",
    "Full Time (on leave)",
    "HEC Nominee",
    "Part Time",
    "Other"
  ];
  final faculties = [
    "Faculty of Agriculture",
    "Faculty of Veterinary Science",
    "Faculty of Science",
    "Faculty of Animal Husbandry",
    "Faculty of Agriculture Engineering and Technology",
    "Faculty of Social Sciences",
    "Faculty of Food, Nutrition and Home Sciences",
    "Faculty of Arts and Huminites",
    "Faculty of Health and Pharmaceutical Sciences",
  ];

  // Degree options
  final degreeOptions = ["MS", "M.Phill", "Ph.D"];

  //Section option
  final sectionOptions = ["A", "B", "nill"];

  // 🔹 Map Faculty → Departments
  final Map<String, List<String>> facultyDepartments = {
    "Faculty of Agriculture": [
      "Agronomy",
      "Entomology",
      "Plant Pathology",
      "Plant Breeding & Genetics",
      "Forestry & Range Management",
      "Institute of Soil And Environmental Sciences",
      "Institute of Horticulture Sciences",
    ],
    "Faculty of Veterinary Science": [
      "Anatomy",
      "Pathology",
      "Clinical Medicine & Surgery",
      "Theriogenology",
      "Parasitology",
      "Institute of Microbiology",
      "Institute of Physiology and Pharmacology",
    ],
    "Faculty of Science": [
      "Botany",
      "Computer Science",
      "Chemistry",
      "Bio-Chemistry",
      "Physics",
      "Mathematics and Statistics",
      "Zoology & Wildlife & Fisheries",
    ],
    "Faculty of Animal Husbandry": [
      "Institute of Animal And Dairy Sciences",
    ],
    "Faculty of Agriculture Engineering and Technology": [
      "Farm Machinery and Power",
      "Fiber and Textile Technology",
      "Irrigation & Drainage",
      "Structures & Environmental Engineering",
      "Energy Systems Engineering",
      "Food Engineering",
    ],
    "Faculty of Social Sciences": [
      "Department of Rural Sociology",
      "Institute of Business Management Sciences",
      "Institute of Agricultural Extension, Education and Rural Development",
      "Institute of Agricultural and Resource Economics",
    ],
    "Faculty of Food, Nutrition and Home Sciences": [
      "National Institute of Food Science and Technology",
      "Institute of Home Sciences",
    ],
    "Faculty of Arts and Huminites": [
      "English and Linguistics",
      "Islamic Studies",
      "Waris Shah Chair",
      "Pakistan Studies / History / Antropology / Psychology",
      "Arts and Design",
    ],
    "Faculty of Health and Pharmaceutical Sciences": [
      "Pharmacy",
      "Epidemiology & Public Health",
      "Medicinal Plants & Nutraceuticals",
    ],
  };

  @override
  void initState() {
    super.initState();
    _checkExistingDetails();
  }

  Future<void> _checkExistingDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 🔹 First get CNIC linked to this UID
      final query = await FirebaseFirestore.instance
          .collection("students")
          .where("uid", isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final cnic = query.docs.first.id; // docId is CNIC
        final data = query.docs.first.data();

        if (data.containsKey("fatherName") &&
            data.containsKey("admissionDate") &&
            data.containsKey("commencingOn")) {
          setState(() {
            existingData = data;
            _alreadyFilled = true;
            _cnicController.text = cnic; // preload CNIC field
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    }
  }


  Future<void> _pickDate({required bool isAdmission}) async {
    DateTime initial = DateTime.now();
    if (isAdmission && _admissionDate != null) initial = _admissionDate!;
    if (!isAdmission && _commencingDate != null) initial = _commencingDate!;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isAdmission) {
          _admissionDate = picked;
        } else {
          if (_admissionDate != null && picked.isBefore(_admissionDate!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "❌ Commencing date cannot be earlier than admission date"),
              ),
            );
          } else {
            _commencingDate = picked;
          }
        }
      });
    }
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;
    if (_admissionDate == null || _commencingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Please select both dates")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not logged in");

      String finalStatus =
      (status == "Other") ? _customStatusController.text.trim() : status!;

      final cnic = _cnicController.text.trim();

      await FirebaseFirestore.instance
          .collection("students")
          .doc(cnic) // 👈 CNIC is the docId
          .set({
        "uid": user.uid, // 👈 link back to Firebase Auth UID
        "fatherName": _fatherController.text.trim(),
        "commencingOn": _commencingDate!.toIso8601String(),
        "admissionDate": _admissionDate!.toIso8601String(),
        "session": session,
        "semester": semester,
        "degree": degree,
        "degreeDiscipline": _disciplineController.text.trim(),
        "section": section,
        "status": finalStatus,
        "cnicnumber": cnic,
        "faculty": faculty,
        "department": department,
        "updatedAt": DateTime.now(),
      }, SetOptions(merge: true)); // 👈 ensures it creates/updates safely

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Details saved successfully")),
      );
      Navigator.pushReplacementNamed(context, '/courses');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  String _beautifyKey(String key) {
    switch (key) {
      case "degree":
        return "Degree";
      case "degreeDiscipline":
        return "Degree Discipline";
      case "section":
        return "Section";
      case "name":
        return "Name";
      case "fatherName":
        return "Father Name";
      case "semester":
        return "Semester";
      case "department":
        return "Department";
      case "faculty":
        return "Faculty";
      case "commencingOn":
        return "Commencing Date";
      case "admissionDate":
        return "Admission Date";
      case "registrationNumber":
        return "Registration No.";
      case "cnicnumber":
        return "CNIC Number";
      case "session":
        return "Session";
      case "status":
        return "Status";
      default:
        return key;
    }
  }

  @override
  void dispose() {
    _fatherController.dispose();
    _customStatusController.dispose();
    _disciplineController.dispose();
    _cnicController.dispose();
    //_sectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Details"),
        backgroundColor: Colors.blueAccent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _alreadyFilled && existingData != null
              ? Column(
            children: [
              Card(
                elevation: 5,
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("✅ Your details are already filled",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Divider(),
                      ...existingData!.entries.map((e) => Padding(
                        padding:
                        const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          "${_beautifyKey(e.key)}: ${e.value}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      )),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                            context, "/updateDetails"),
                        icon: const Icon(Icons.edit),
                        label: const Text("Update Details"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, "/courses"),
                        icon: const Icon(Icons.book),
                        label: const Text("Go to Courses"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
              : Form(
            key: _formKey,
            child: Column(
              children: [
                _buildDropdown(
                    label: "Faculty",
                    icon: Icons.account_balance,
                    items: faculties,
                    value: faculty,
                    onChanged: (v) {
                      setState(() {
                        faculty = v;
                        department = null;
                      });
                    }),
                if (faculty != null)
                  _buildDropdown(
                      label: "Department",
                      icon: Icons.business,
                      items: facultyDepartments[faculty] ?? [],
                      value: department,
                      onChanged: (v) => setState(() => department = v)),
                _buildDropdown(
                    label: "Degree",
                    icon: Icons.menu_book,
                    items: degreeOptions,
                    value: degree,
                    onChanged: (v) => setState(() => degree = v)),
                _buildTextField(
                    label: "Degree Discipline",
                    icon: Icons.book,
                    controller: _disciplineController),
                _buildDropdown(
                    label: "Section",
                    icon: Icons.menu_book,
                    items: sectionOptions,
                    value: section,
                    onChanged: (v) => setState(() => section = v)),
                _buildDropdown(
                    label: "Session",
                    icon: Icons.calendar_month,
                    items: sessions,
                    value: session,
                    onChanged: (v) => setState(() => session = v)),
                _buildDropdown(
                    label: "Semester",
                    icon: Icons.school,
                    items: semesters,
                    value: semester,
                    onChanged: (v) => setState(() => semester = v)),
                _buildTextField(
                    label: "Father Name",
                    icon: Icons.person,
                    controller: _fatherController),
                _buildTextField(
                    label: "CNIC Number",
                    icon: Icons.perm_identity,
                    controller: _cnicController),
                _buildDateField(
                    label: "Select Admission Date",
                    icon: Icons.event,
                    date: _admissionDate,
                    onTap: () => _pickDate(isAdmission: true)),
                _buildDateField(
                    label: "Select Commencing Date",
                    icon: Icons.date_range,
                    date: _commencingDate,
                    onTap: () => _pickDate(isAdmission: false)),
                _buildDropdown(
                    label: "Status",
                    icon: Icons.verified_user,
                    items: statuses,
                    value: status,
                    onChanged: (v) => setState(() => status = v)),
                if (status == "Other")
                  _buildTextField(
                      label: "Enter Custom Status",
                      icon: Icons.edit_note,
                      controller: _customStatusController),
                const SizedBox(height: 20),
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                  onPressed: _saveDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text("Save & Continue"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required List<String> items,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? "Please select $label" : null,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        validator: (v) => (v == null || v.isEmpty) ? "Enter your $label" : null,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        tileColor: Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon),
        title: Text(date == null
            ? label
            : "${date.day}/${date.month}/${date.year}"),
        trailing: const Icon(Icons.calendar_today),
        onTap: onTap,
      ),
    );
  }
}
