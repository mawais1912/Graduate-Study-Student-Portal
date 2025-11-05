import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? studentData;
  List<Map<String, dynamic>> submittedCourses = [];
  bool _loading = true;
  Uint8List? logoBytes;
  String? studentDocId; // 👈 CNIC ID

  final requiredFields = [
    "name",
    "fatherName",
    "semester",
    "degree",
    "degreeDiscipline",
    "section",
    "department",
    "faculty",
    "commencingOn",
    "admissionDate",
    "registrationNumber",
    "session",
    "cnicnumber",
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final bytes = await rootBundle.load("assets/images/logo.jpeg");
    setState(() {
      logoBytes = bytes.buffer.asUint8List();
    });
  }

  Future<void> _fetchData() async {
    if (user == null) return;
    try {
      // 🔹 First find CNIC docId from uid
      final query = await FirebaseFirestore.instance
          .collection("students")
          .where("uid", isEqualTo: user!.uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      studentDocId = query.docs.first.id;
      final doc = await FirebaseFirestore.instance
          .collection("students")
          .doc(studentDocId)
          .get();

      final courseworkDoc = await FirebaseFirestore.instance
          .collection("students")
          .doc(studentDocId)
          .collection("coursework")
          .doc("submittedWork")
          .get();

      final List<Map<String, dynamic>> tempCourses = [];

      if (courseworkDoc.exists) {
        final courseWork = courseworkDoc.data()?["courseWork"] ?? {};
        final currentSemester = doc.data()?["semester"];
        final currentSession = doc.data()?["session"];

        for (var entry in courseWork.entries) {
          if (entry.value == "Yes") {
            final courseSnap = await FirebaseFirestore.instance
                .collection("courses")
                .doc(entry.key)
                .get();

            if (courseSnap.exists) {
              final courseData = courseSnap.data()!;
              if (courseData["semester"] == currentSemester &&
                  courseData["session"] == currentSession) {
                tempCourses.add({
                  "id": entry.key,
                  "courseCode": courseData["courseCode"],
                  "courseTitle": courseData["courseTitle"],
                  "creditHour": courseData["creditHour"],
                  "courseStatus": courseData["courseStatus"],
                  "faculty": courseData["faculty"],
                  "department": courseData["department"],
                  "section": courseData["section"] ?? "N/A",
                  "session": courseData["session"],
                  "semester": courseData["semester"],
                  "degree": courseData["degree"] ?? "",
                  "degreeDiscipline": courseData["degreeDiscipline"] ?? "",
                });
              }
            }
          }
        }
      }

      setState(() {
        studentData = doc.data();
        submittedCourses = tempCourses;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error loading data: $e")),
      );
    }
  }

  /// Generate PDF with all new fields
  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes!) : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              if (logo != null) pw.Image(logo, width: 60, height: 60),
              pw.SizedBox(width: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("University of Agriculture Faisalabad",
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Student Report",
                      style: pw.TextStyle(
                          fontSize: 16, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),

          // Student Details
          pw.Text("Student Details",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(5),
            },
            children: (studentData?.entries ?? [])
                .where((e) => requiredFields.contains(e.key))
                .map((e) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(_beautifyKey(e.key),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(e.value.toString()),
                ),
              ],
            ))
                .toList(),
          ),
          pw.SizedBox(height: 20),

          // Submitted Courses
          pw.Text("Submitted Courses (Current Semester)",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          if (submittedCourses.isEmpty)
            pw.Text("No courses marked as submitted",
                style: const pw.TextStyle(fontSize: 14))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue200),
                  children: [
                    _pdfCell("Code", isHeader: true),
                    _pdfCell("Title", isHeader: true),
                    _pdfCell("CH", isHeader: true),
                    _pdfCell("Status", isHeader: true),
                    _pdfCell("Dept", isHeader: true),
                  ],
                ),
                ...submittedCourses.map((c) => pw.TableRow(
                  children: [
                    _pdfCell(c['courseCode']),
                    _pdfCell(c['courseTitle']),
                    _pdfCell(c['creditHour'].toString()),
                    _pdfCell(c['courseStatus']),
                    _pdfCell("${c['department']} (${c['section']})"),
                  ],
                )),
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
  }


  pw.Widget _pdfCell(String text, {bool isHeader = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text,
        style: isHeader
            ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
            : const pw.TextStyle()),
  );

  String _beautifyKey(String key) {
    switch (key) {
      case "degreeDiscipline":
        return "Discipline";
      case "fatherName":
        return "Father Name";
      case "registrationNumber":
        return "Registration No.";
      case "cnicnumber":
        return "CNIC Number";
      case "commencingOn":
        return "Commencing Date";
      case "admissionDate":
        return "Admission Date";
      default:
        return key[0].toUpperCase() + key.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Preview Information"),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Info
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("👤 Student Details",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    ...(studentData?.entries ?? [])
                        .where((e) => requiredFields.contains(e.key))
                        .map((e) => Padding(
                      padding:
                      const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        "${_beautifyKey(e.key)}: ${e.value}",
                        style: const TextStyle(fontSize: 15),
                      ),
                    )),
                  ],
                ),
              ),
            ),

            // Courses
            const Text("📘 Submitted Courses (Current Semester)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            if (submittedCourses.isEmpty)
              const Text("No courses marked as submitted ❌")
            else
              ...submittedCourses.map((c) => Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 4,
                child: ListTile(
                  leading: const Icon(Icons.book,
                      color: Colors.blueAccent),
                  title:
                  Text("${c['courseCode']} - ${c['courseTitle']}"),
                  subtitle: Text(
                      "Status: ${c['courseStatus']}, CH: ${c['creditHour']}\n"
                          "Dept: ${c['department']}, Section: ${c['section']}"),
                ),
              )),

            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: _generatePdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Download PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
