import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateDetailsScreen extends StatefulWidget {
  const UpdateDetailsScreen({super.key});

  @override
  State<UpdateDetailsScreen> createState() => _UpdateDetailsScreenState();
}

class _UpdateDetailsScreenState extends State<UpdateDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fatherController = TextEditingController();
  final _regNoController = TextEditingController();
  final _cnicController = TextEditingController();
  final _disciplineController = TextEditingController();

  DateTime? _commencingDate;
  DateTime? _admissionDate;

  String? semester;
  String? faculty;
  String? department;
  String? session;
  String? degree;
  String? section;

  bool _loading = false;
  bool _hasChanged = false;
  final user = FirebaseAuth.instance.currentUser;

  String? studentDocId; // 👈 will store CNIC

  final semesters = [
    "Semester 1", "Semester 2", "Semester 3", "Semester 4",
    "Semester 5", "Semester 6", "Semester 7", "Semester 8", "Semester 9","Semester 10",
    "Semester 11",
    "Semester 12",
  ];
  final sessions = ["Winter 2025-2026", "Spring 2026"];
  final faculties = [
    "Faculty of Agriculture",
    "Faculty of Veterinary Science",
    "Faculty of Science",
    "Faculty of Animal Husbandry",
    "Faculty of Agriculture Engineering and Technology",
    "Faculty of Social Sciences",
    "Faculty of Food, Nutrition and Home Sciences",
    "Faculty of Arts and Humanities",
    "Faculty of Health and Pharmaceutical Sciences",
  ];
  final degrees = ["MS", "M.Phill", "Ph.D"];
  final sections = ["A", "B", "nill"];

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
    "Faculty of Arts and Humanities": [
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

  Map<String, dynamic>? studentData;

  @override
  void initState() {
    super.initState();
    _resolveStudentDoc();
    for (var c in [
      _nameController,
      _fatherController,
      _regNoController,
      _cnicController,
      _disciplineController
    ]) {
      c.addListener(() => setState(() => _hasChanged = true));
    }
  }

  Future<void> _resolveStudentDoc() async {
    if (user == null) return;
    try {
      // find student by uid → get CNIC as docId
      final snap = await FirebaseFirestore.instance
          .collection("students")
          .where("uid", isEqualTo: user!.uid)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        setState(() {
          studentDocId = snap.docs.first.id;
        });
        _loadStudentData();
      } else {
        _showSnack("❌ Student record not found", isError: true);
      }
    } catch (e) {
      _showSnack("❌ Error resolving student doc: $e", isError: true);
    }
  }

  Future<void> _loadStudentData() async {
    if (studentDocId == null) return;
    try {
      final doc =
      await FirebaseFirestore.instance.collection("students").doc(studentDocId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          studentData = data;
          _nameController.text = data["name"] ?? "";
          _fatherController.text = data["fatherName"] ?? "";
          _regNoController.text = data["registrationNumber"] ?? "";
          _cnicController.text = data["cnicnumber"] ?? "";
          section = data["section"];
          degree = data["degree"];
          _disciplineController.text = data["degreeDiscipline"] ?? "";
          semester = data["semester"];
          faculty = data["faculty"];
          department = data["department"];
          session = data["session"];
          _admissionDate =
          data["admissionDate"] != null ? DateTime.tryParse(data["admissionDate"]) : null;
          _commencingDate =
          data["commencingOn"] != null ? DateTime.tryParse(data["commencingOn"]) : null;
          _hasChanged = false;
        });
      }
    } catch (e) {
      _showSnack("❌ Error loading details: $e", isError: true);
    }
  }

  Future<void> _pickDate(bool isAdmission) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isAdmission) {
          _admissionDate = picked;
        } else {
          if (_admissionDate != null && picked.isBefore(_admissionDate!)) {
            _showSnack("❌ Commencing Date cannot be before Admission Date", isError: true);
            return;
          }
          _commencingDate = picked;
        }
        _hasChanged = true;
      });
    }
  }

  Future<void> _updateDetails() async {
    if (!_formKey.currentState!.validate()) return;
    if (_admissionDate == null || _commencingDate == null) {
      _showSnack("❌ Please select both dates", isError: true);
      return;
    }
    if (studentDocId == null) return;

    setState(() => _loading = true);
    try {
      final newCnic = _cnicController.text.trim();

      final updatedData = {
        "name": _nameController.text.trim(),
        "fatherName": _fatherController.text.trim(),
        "registrationNumber": _regNoController.text.trim(),
        "cnicnumber": newCnic,
        "uid": user!.uid,                 // ✅ always keep UID
        "email": user!.email,             // ✅ keep email in sync
        "section": section,
        "degree": degree,
        "degreeDiscipline": _disciplineController.text.trim().toLowerCase(),
        "semester": semester,
        "faculty": faculty,
        "department": department,
        "session": session,
        "admissionDate": _admissionDate!.toIso8601String(),
        "commencingOn": _commencingDate!.toIso8601String(),
        "updatedAt": DateTime.now(),
      };

      if (newCnic == studentDocId) {
        // 🔹 Case 1: CNIC didn’t change → just update
        await FirebaseFirestore.instance
            .collection("students")
            .doc(studentDocId)
            .update(updatedData);
      } else {
        // 🔹 Case 2: CNIC changed → check for duplicate first
        final exists = await FirebaseFirestore.instance
            .collection("students")
            .doc(newCnic)
            .get();

        if (exists.exists) {
          _showSnack("❌ This CNIC already exists!", isError: true);
          setState(() => _loading = false);
          return;
        }

        final oldRef =
        FirebaseFirestore.instance.collection("students").doc(studentDocId);
        final newRef =
        FirebaseFirestore.instance.collection("students").doc(newCnic);

        // copy main data
        await newRef.set(updatedData);

        // copy coursework
        final cwSnap = await oldRef.collection("coursework").get();
        for (var doc in cwSnap.docs) {
          await newRef.collection("coursework").doc(doc.id).set(doc.data());
        }

        // copy notifications
        final notifSnap = await oldRef.collection("notifications").get();
        for (var doc in notifSnap.docs) {
          await newRef.collection("notifications").doc(doc.id).set(doc.data());
        }

        // copy enrolled_courses
        final enrolledSnap = await oldRef.collection("enrolled_courses").get();
        for (var doc in enrolledSnap.docs) {
          await newRef.collection("enrolled_courses").doc(doc.id).set(doc.data());
        }

        // delete old doc
        await oldRef.delete();

        studentDocId = newCnic; // 👈 update local reference
      }

      _showSnack("✅ Details updated successfully");
      _loadStudentData();
    } catch (e) {
      _showSnack("❌ Failed to update: $e", isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }





  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Update Details"), backgroundColor: Colors.blueAccent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (studentData != null) _buildSummaryCard(),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(_nameController, "Name", Icons.person),
                  _buildTextField(_fatherController, "Father Name", Icons.person),
                  _buildTextField(_regNoController, "Registration Number", Icons.badge),
                  _buildTextField(_cnicController, "CNIC Number", Icons.person),
                  _buildDropdown("Section", sections, section,
                          (v) => setState(() => {section = v, _hasChanged = true}), Icons.group),
                  _buildDropdown("Degree", degrees, degree,
                          (v) => setState(() => {degree = v, _hasChanged = true}), Icons.school),
                  _buildTextField(_disciplineController, "Degree Discipline", Icons.menu_book),
                  _buildDropdown("Session", sessions, session,
                          (v) => setState(() => {session = v, _hasChanged = true}), Icons.calendar_month),
                  _buildDropdown("Semester", semesters, semester,
                          (v) => setState(() => {semester = v, _hasChanged = true}), Icons.school),
                  _buildDropdown("Faculty", faculties, faculty, (v) {
                    setState(() {
                      faculty = v;
                      department = null;
                      _hasChanged = true;
                    });
                  }, Icons.account_balance),
                  if (faculty != null)
                    _buildDropdown("Department", facultyDepartments[faculty] ?? [], department,
                            (v) => setState(() => {department = v, _hasChanged = true}), Icons.business),
                  _buildDateTile("Admission Date", _admissionDate, () => _pickDate(true)),
                  _buildDateTile("Commencing Date", _commencingDate, () => _pickDate(false)),
                  const SizedBox(height: 20),
                  _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                    onPressed: _hasChanged ? _updateDetails : null,
                    icon: const Icon(Icons.save),
                    label: const Text("Update"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("👤 Current Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const Divider(),
          _summaryRow("Name", studentData!["name"]),
          _summaryRow("Father Name", studentData!["fatherName"]),
          _summaryRow("Reg. No", studentData!["registrationNumber"]),
          _summaryRow("CNIC Number", studentData!["cnicnumber"]),
          _summaryRow("Section", studentData!["section"]),
          _summaryRow("Session", studentData!["session"]),
          _summaryRow("Semester", studentData!["semester"]),
          _summaryRow("Degree", studentData!["degree"]),
          _summaryRow("Discipline", studentData!["degreeDiscipline"]),
          _summaryRow("Faculty", studentData!["faculty"]),
          _summaryRow("Department", studentData!["department"]),
          _summaryRow("Admission Date", studentData!["admissionDate"]),
          _summaryRow("Commencing Date", studentData!["commencingOn"]),
        ]),
      ),
    );
  }

  Widget _summaryRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text("$label: ${value ?? 'Not provided'}"),
    );
  }

  Widget _buildTextField(TextEditingController c, String label, IconData icon, {String? pattern}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return "Enter $label";
          if (pattern != null && !RegExp(pattern).hasMatch(v)) return "Invalid $label format";
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown(
      String label, List<String> items, String? value, Function(String?) onChanged, IconData icon) {
    final safeValue = items.contains(value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? "Select $label" : null,
      ),
    );
  }

  Widget _buildDateTile(String label, DateTime? date, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        tileColor: Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: const Icon(Icons.date_range),
        title: Text(date == null ? label : "${date.day}/${date.month}/${date.year}"),
        trailing: const Icon(Icons.calendar_today),
        onTap: onTap,
      ),
    );
  }
}
