import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, String> _newSelections = {};

  String? studentDocId; // 👈 CNIC will be stored here
  String? department;
  String? semester;
  String? session;
  String? section;
  String? degree;
  String? degreeDiscipline;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentDetails();
  }

  Future<void> _fetchStudentDetails() async {
    if (user == null) return;

    try {
      // 🔹 Find student doc by uid → get CNIC
      final query = await FirebaseFirestore.instance
          .collection("students")
          .where("uid", isEqualTo: user!.uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        setState(() {
          studentDocId = doc.id; // CNIC
          department = doc["department"];
          semester = doc["semester"];
          session = doc["session"];
          section = doc["section"];
          degree = doc["degree"];
          degreeDiscipline = (doc["degreeDiscipline"] ?? "").toString().toLowerCase();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ No student details found")),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error fetching student details: $e")),
      );
    }
  }

  Future<void> _submitSelections(Map<String, dynamic> submittedWork) async {
    try {
      if (studentDocId == null) return;
      if (_newSelections.isEmpty) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("💾 Saving your selections...")),
      );

      final updatedWork = Map<String, dynamic>.from(submittedWork);
      _newSelections.forEach((key, value) {
        updatedWork[key] = value;
      });

      await FirebaseFirestore.instance
          .collection("students")
          .doc(studentDocId) // use CNIC
          .collection("coursework")
          .doc("submittedWork")
          .set({
        "department": department,
        "semester": semester,
        "session": session,
        "section": section,
        "degree": degree,
        "degreeDiscipline": degreeDiscipline,
        "courseWork": updatedWork,
        "submittedAt": DateTime.now(),
      });

      await FirebaseFirestore.instance
          .collection("students")
          .doc(studentDocId)
          .collection("notifications")
          .add({
        "message":
        "📘 Coursework submitted for $department - $semester ($session - $section - $degree $degreeDiscipline)",
        "success": true,
        "timestamp": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Course work submitted successfully")),
      );

      setState(() {
        _newSelections.clear();
      });
    } catch (e) {
      if (studentDocId != null) {
        await FirebaseFirestore.instance
            .collection("students")
            .doc(studentDocId)
            .collection("notifications")
            .add({
          "message": "❌ Coursework submission failed: $e",
          "success": false,
          "timestamp": FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error submitting: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (studentDocId == null) {
      return const Scaffold(
        body: Center(child: Text("❌ Student record not found")),
      );
    }

    final courseworkStream = FirebaseFirestore.instance
        .collection("students")
        .doc(studentDocId)
        .collection("coursework")
        .doc("submittedWork")
        .snapshots();

    // ✅ Filter courses by student details
    final coursesStream = FirebaseFirestore.instance
        .collection("courses")
        .where("department", isEqualTo: department)
        .where("semester", isEqualTo: semester)
        .where("session", isEqualTo: session)
        .where("section", isEqualTo: section)
        .where("degree", isEqualTo: degree)
        .where("degreeDiscipline", isEqualTo: degreeDiscipline?.toLowerCase())
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Courses"),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: courseworkStream,
        builder: (context, cwSnapshot) {
          if (cwSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final submittedWork = cwSnapshot.data?.data() != null
              ? Map<String, dynamic>.from(cwSnapshot.data!["courseWork"] ?? {})
              : <String, dynamic>{};

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.amber.shade100,
                padding: const EdgeInsets.all(12),
                child: const Text(
                  "⚠️ You cannot edit already submitted coursework here.\nUse the Enrolled Courses screen to make changes.",
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: coursesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text("📭 No courses available"));
                    }

                    final courses = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        final course = courses[index];
                        final courseId = course.id;
                        final courseTitle = course["courseTitle"];
                        final courseCode = course["courseCode"];
                        final creditHours = course["creditHour"];
                        final status = course["courseStatus"];

                        final alreadySubmitted = submittedWork[courseId];

                        return Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blueAccent.withOpacity(0.7),
                                  Colors.blueAccent,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("📘 $courseCode - $courseTitle",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white)),
                                const SizedBox(height: 6),
                                Text("Credit Hours: $creditHours",
                                    style:
                                    const TextStyle(color: Colors.white70)),
                                Text("Status: $status",
                                    style:
                                    const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 12),
                                if (alreadySubmitted != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.lock,
                                          color: Colors.white, size: 20),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          "✅ Already Submitted: $alreadySubmitted (edit in Enrolled Courses)",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      const Text("Course work submitted:",
                                          style:
                                          TextStyle(color: Colors.white)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Radio<String>(
                                              value: "Yes",
                                              groupValue:
                                              _newSelections[courseId],
                                              onChanged: (val) {
                                                setState(() => _newSelections[
                                                courseId] = val!);
                                              },
                                              activeColor: Colors.white,
                                            ),
                                            const Text("Yes",
                                                style: TextStyle(
                                                    color: Colors.white)),
                                            Radio<String>(
                                              value: "No",
                                              groupValue:
                                              _newSelections[courseId],
                                              onChanged: (val) {
                                                setState(() => _newSelections[
                                                courseId] = val!);
                                              },
                                              activeColor: Colors.white,
                                            ),
                                            const Text("No",
                                                style: TextStyle(
                                                    color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _newSelections.isEmpty
                          ? null
                          : () => _submitSelections(submittedWork),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        disabledBackgroundColor: Colors.grey,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon:
                      const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text("Save Selections",
                          style:
                          TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, "/enrolled");
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: Colors.blueAccent),
                      ),
                      icon: const Icon(Icons.book, color: Colors.blueAccent),
                      label: const Text("Go to Enrolled Courses",
                          style: TextStyle(
                              fontSize: 16, color: Colors.blueAccent)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
