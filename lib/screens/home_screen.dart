import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String studentName = "Loading...";
  String name="";
  String studentEmail = "";
  int totalCourses = 0;
  int totalCredits = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _getStudentData();
    _fetchStats();
  }

  Future<void> _getStudentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        studentEmail = user.email ?? "";
      });

      try {
        final doc = await FirebaseFirestore.instance
            .collection("students")
            .doc(user.uid)
            .get();

        if (doc.exists) {
          setState(() {
            studentName = doc["name"] ?? "Student";
          });
        } else {
          setState(() {
            studentName = "No Name Found";
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error fetching data: $e")),
          );
        }
      }
    }
  }

  Future<void> _fetchStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final cwDoc = await FirebaseFirestore.instance
          .collection("students")
          .doc(user.uid)
          .collection("coursework")
          .doc("submittedWork")
          .get();

      if (cwDoc.exists) {
        final data = cwDoc.data();
        print("📘 Coursework raw data: $data"); // 👈 debug log

        if (data != null && data["courseWork"] != null) {
          final Map<String, dynamic> courses =
          Map<String, dynamic>.from(data["courseWork"]);
          int credits = 0;
          int courseCount = 0;

          for (var entry in courses.entries) {
            if (entry.value == "Yes") {
              final courseDoc = await FirebaseFirestore.instance
                  .collection("courses")
                  .doc(entry.key)
                  .get();

              if (courseDoc.exists) {
                courseCount++; // 👈 only count valid courses
                final cData = courseDoc.data()!;
                final ch = int.tryParse(cData["creditHour"].toString()) ?? 0;
                credits += ch;
              } else {
                print("⚠️ Skipping non-existing course ID: ${entry.key}");
              }
            }
          }

          setState(() {
            totalCourses = courseCount;
            totalCredits = credits;
            _loadingStats = false;
          });
        } else {
          setState(() {
            totalCourses = 0;
            totalCredits = 0;
            _loadingStats = false;
          });
        }
      } else {
        print("⚠️ No submittedWork document found.");
        setState(() {
          totalCourses = 0;
          totalCredits = 0;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading stats: $e")),
        );
      }
      setState(() {
        totalCourses = 0;
        totalCredits = 0;
        _loadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Portal - Home"),
        backgroundColor: Colors.blueAccent,
      ),
      drawer: _buildDrawer(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 600;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- Stats Card ---
               /* Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _loadingStats
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat("Total Courses", totalCourses,
                            color: Colors.blueAccent),
                        _stat("Total Credit Hours", totalCredits,
                            color: Colors.green),
                      ],
                    ),
                  ),
                ), */

                // --- Dashboard Cards ---
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: isWide ? 2 : 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildCard(
                      icon: Icons.person,
                      title: "Profile",
                      color: Colors.purple,
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                    ),
                    _buildCard(
                      icon: Icons.info,
                      title: "Details Info",
                      color: Colors.orange,
                      onTap: () => Navigator.pushNamed(context, '/details'),
                    ),
                    _buildCard(
                      icon: Icons.update,
                      title: "Update Details",
                      color: Colors.redAccent,
                      onTap: () =>
                          Navigator.pushNamed(context, '/updateDetails'),
                    ),
                    _buildCard(
                      icon: Icons.book,
                      title: "Enrolled Courses",
                      color: Colors.teal,
                      onTap: () => Navigator.pushNamed(context, '/enrolled'),
                    ),
                    _buildCard(
                      icon: Icons.preview,
                      title: "Preview",
                      color: Colors.green,
                      onTap: () => Navigator.pushNamed(context, '/preview'),
                    ),
                    _buildCard(
                      icon: Icons.notifications,
                      title: "Notifications",
                      color: Colors.blue,
                      onTap: () => Navigator.pushNamed(context, '/notifications'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Drawer
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(studentName),
            accountEmail: Text(studentEmail),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.blueAccent),
            ),
            decoration: const BoxDecoration(color: Colors.blueAccent),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text("Details Info"),
            onTap: () => Navigator.pushNamed(context, '/details'),
          ),
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text("Update Details"),
            onTap: () => Navigator.pushNamed(context, '/updateDetails'),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text("Enrolled Courses"),
            onTap: () => Navigator.pushNamed(context, '/enrolled'),
          ),
          ListTile(
            leading: const Icon(Icons.preview),
            title: const Text("Preview"),
            onTap: () => Navigator.pushNamed(context, '/preview'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text("Notifications"),
            onTap: () => Navigator.pushNamed(context, '/notifications'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }

  /// Dashboard Card
  Widget _buildCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Stats Widget
  Widget _stat(String label, int? value, {required Color color}) {
    final safeValue = value ?? 0;

    return Column(
      children: [
        Text(
          label,
          style:
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Text(
          safeValue.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
