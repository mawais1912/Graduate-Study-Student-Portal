import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class EnrolledCoursesScreen extends StatefulWidget {
  const EnrolledCoursesScreen({super.key});

  @override
  State<EnrolledCoursesScreen> createState() => _EnrolledCoursesScreenState();
}

class _EnrolledCoursesScreenState extends State<EnrolledCoursesScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _loading = true;
  Map<String, dynamic> _courseWork = {};
  Map<String, dynamic>? studentData;
  Uint8List? logoBytes;

  @override
  void initState() {
    super.initState();
    _fetchCoursework();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final bytes = await rootBundle.load("assets/images/logo.jpeg");
    setState(() {
      logoBytes = bytes.buffer.asUint8List();
    });
  }

  Future<void> _fetchCoursework() async {
    if (user == null) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection("students")
          .where("uid", isEqualTo: user!.uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _loading = false);
        _showSnack("❌ No student record found");
        return;
      }

      final studentDoc = query.docs.first;
      final studentDocId = studentDoc.id;
      studentData = studentDoc.data();

      final cwDoc = await FirebaseFirestore.instance
          .collection("students")
          .doc(studentDocId)
          .collection("coursework")
          .doc("submittedWork")
          .get();

      if (cwDoc.exists) {
        setState(() {
          _courseWork = cwDoc["courseWork"] ?? {};
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      _showSnack("❌ Error fetching enrolled courses: $e");
    }
  }

  Future<void> _updateCourseStatus(String courseId, String status) async {
    try {
      if (user == null) return;
      final query = await FirebaseFirestore.instance
          .collection("students")
          .where("uid", isEqualTo: user!.uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showSnack("❌ No student record found");
        return;
      }

      final studentDocId = query.docs.first.id;

      setState(() {
        _courseWork[courseId] = status;
      });

      await FirebaseFirestore.instance
          .collection("students")
          .doc(studentDocId)
          .collection("coursework")
          .doc("submittedWork")
          .update({"courseWork.$courseId": status});

      _showSnack("✅ Updated course status to $status");
    } catch (e) {
      _showSnack("❌ Error updating status: $e");
    }
  }

  Future<void> _deleteCourse(String courseId, String courseTitle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete $courseTitle?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (user == null) return;

      final query = await FirebaseFirestore.instance
          .collection("students")
          .where("uid", isEqualTo: user!.uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showSnack("❌ No student record found");
        return;
      }

      final studentDocId = query.docs.first.id;

      setState(() {
        _courseWork.remove(courseId);
      });

      await FirebaseFirestore.instance
          .collection("students")
          .doc(studentDocId)
          .collection("coursework")
          .doc("submittedWork")
          .update({"courseWork.$courseId": FieldValue.delete()});

      _showSnack("🗑️ Course deleted successfully");
    } catch (e) {
      _showSnack("❌ Error deleting course: $e");
    }
  }

  Future<void> _generatePdf() async {
    try {
      final pdf = pw.Document();
      final logo = logoBytes != null ? pw.MemoryImage(logoBytes!) : null;
      final now = DateTime.now();

      // 🔹 Build course list
      List<Map<String, dynamic>> courseList = [];
      for (var entry in _courseWork.entries) {
        final doc = await FirebaseFirestore.instance
            .collection("courses")
            .doc(entry.key)
            .get();
        if (doc.exists) {
          final course = doc.data()!;
          courseList.add({
            "code": course["courseCode"] ?? "",
            "title": course["courseTitle"] ?? "",
            "status": entry.value,
            "ch": course["creditHour"].toString(),
            "session": course["session"] ?? "",
            "semester": course["semester"] ?? "",
          });
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            // 🔹 Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null) pw.Image(logo, width: 60, height: 60),
                pw.SizedBox(width: 20),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("University of Agriculture Faisalabad",
                        style: pw.TextStyle(
                            fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Enrolled Courses Report",
                        style: pw.TextStyle(
                            fontSize: 16, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),

            pw.Text("Generated on: "
                "${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}"),
            pw.SizedBox(height: 20),

            // 🔹 Student Details
            if (studentData != null) ...[
              pw.Text("Student Details",
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                children: [
                  _infoRow("Name", studentData!["name"] ?? ""),
                  _infoRow("Reg. No", studentData!["registrationNumber"] ?? ""),
                  _infoRow("Degree", studentData!["degree"] ?? ""),
                  _infoRow("Discipline", studentData!["degreeDiscipline"] ?? ""),
                  _infoRow("Section", studentData!["section"] ?? ""),
                  _infoRow("Faculty", studentData!["faculty"] ?? ""),
                  _infoRow("Department", studentData!["department"] ?? ""),
                  _infoRow("Session", studentData!["session"] ?? ""),
                  _infoRow("Semester", studentData!["semester"] ?? ""),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // 🔹 Courses Table
            pw.Text("Courses",
                style:
                pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration:
                  const pw.BoxDecoration(color: PdfColors.blue200),
                  children: [
                    _tableHeader("Code"),
                    _tableHeader("Title"),
                    _tableHeader("CH"),
                    _tableHeader("Status"),
                    _tableHeader("Session"),
                    _tableHeader("Semester"),
                  ],
                ),
                ...courseList.map((c) => pw.TableRow(children: [
                  _tableCell(c["code"]),
                  _tableCell(c["title"]),
                  _tableCell(c["ch"]),
                  _tableCell(
                      c["status"] == "Yes" ? "Submitted" : "Not Submitted"),
                  _tableCell(c["session"]),
                  _tableCell(c["semester"]),
                ])),
              ],
            ),
          ],
          // 👇 Footer added here
          footer: (context) => pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              "Created by Awais Khan",
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
      _showSnack("📄 PDF generated successfully");
    } catch (e) {
      _showSnack("❌ PDF generation failed: $e");
    }
  }

// 🔹 Helpers
  pw.TableRow _infoRow(String key, String value) => pw.TableRow(children: [
    pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(key,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ),
    pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(value),
    ),
  ]);

  pw.Widget _tableHeader(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));

  pw.Widget _tableCell(String text) =>
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text));


  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_courseWork.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Enrolled Courses")),
        body: const Center(child: Text("📭 No enrolled courses found")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Enrolled Courses"),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generatePdf,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text("PDF"),
        backgroundColor: Colors.blueAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: _courseWork.entries.map((entry) {
          String courseId = entry.key;
          String status = entry.value;

          return FutureBuilder<DocumentSnapshot>(
            future:
            FirebaseFirestore.instance.collection("courses").doc(courseId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox();
              }
              final course = snapshot.data!;
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 5,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${course["courseCode"]} - ${course["courseTitle"]}",
                          style: TextStyle(
                              fontSize: screenWidth < 400 ? 16 : 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent)),
                      const SizedBox(height: 8),
                      Text("Department: ${course["department"] is Map ? course["department"]["name"] ?? "" : course["department"]}"),
                      Text("Semester: ${course["semester"] is Map ? course["semester"]["name"] ?? "" : course["semester"]}"),
                      Text("Session: ${course["session"] is Map ? course["session"]["name"] ?? "" : course["session"]}"),
                      Text("Credit Hours: ${course["creditHour"] is Map ? course["creditHour"]["value"] ?? "" : course["creditHour"]}"),
                      Text(
                          "Section: ${studentData?["section"] ?? "N/A"} | Degree: ${studentData?["degree"] ?? ""} (${studentData?["degreeDiscipline"] ?? "N/A"})"),
                      const SizedBox(height: 10),
                      Text(
                        "Coursework: ${status == "Yes" ? "✅ Submitted" : "❌ Not Submitted"}",
                        style: TextStyle(
                            color: status == "Yes" ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _updateCourseStatus(courseId, "Yes"),
                            icon: const Icon(Icons.check),
                            label: const Text("Mark Yes"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _updateCourseStatus(courseId, "No"),
                            icon: const Icon(Icons.close),
                            label: const Text("Mark No"),
                            style:
                            ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          ),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _deleteCourse(courseId, course["courseTitle"]),
                            icon: const Icon(Icons.delete),
                            label: const Text("Delete"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
