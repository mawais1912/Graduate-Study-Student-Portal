import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? studentData;
  String? studentDocId; // CNIC
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    if (user == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection("students")
          .where("uid", isEqualTo: user!.uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        setState(() {
          studentDocId = doc.id; // CNIC
          studentData = doc.data();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error: $e")),
        );
      }
    }
  }

  Future<void> _logNotification(String message, bool success) async {
    if (studentDocId == null) return;
    await FirebaseFirestore.instance
        .collection("students")
        .doc(studentDocId)
        .collection("notifications")
        .add({
      "message": message,
      "success": success,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateFirestoreField(String field, String value) async {
    if (studentDocId == null) return;
    await FirebaseFirestore.instance
        .collection("students")
        .doc(studentDocId)
        .update({field: value});
  }

  Future<void> _updateField(String field, String oldValue) async {
    final controller = TextEditingController(text: oldValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Update $field"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: field),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Update"),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        if (field == "email") {
          // Update FirebaseAuth email
          await user!.updateEmail(result);
          // Also update in Firestore
          await _updateFirestoreField("email", result);
        } else if (field == "password") {
          await user!.updatePassword(result);
        } else {
          await _updateFirestoreField(field, result);
        }

        setState(() => studentData![field] = result);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ $field updated successfully")),
          );
        }

        await _logNotification("Profile field '$field' updated", true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Error updating $field: $e")),
          );
        }
        await _logNotification("Failed to update '$field'", false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    try {
      if (studentDocId != null) {
        await FirebaseFirestore.instance
            .collection("students")
            .doc(studentDocId)
            .delete();
      }
      await user!.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Account deleted")),
      );

      await _logNotification("Account deleted", true);
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error: $e")),
        );
      }
      await _logNotification("Failed to delete account", false);
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Logged out successfully")),
      );

      await _logNotification("User logged out", true);
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Logout failed: $e")),
        );
      }
      await _logNotification("Logout failed: $e", false);
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
        title: const Text("My Profile"),
        backgroundColor: Colors.blueAccent,
      ),
      body: studentData == null
          ? const Center(child: Text("No data found"))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent.withOpacity(0.8),
                      Colors.blueAccent
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person,
                          size: 40, color: Colors.blueAccent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(studentData!["name"] ?? "Student",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          Text(studentData!["email"] ?? user!.email ?? "",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                          Text(
                              "Reg #: ${studentData!["registrationNumber"] ?? ""}",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Editable Info
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Column(
                children: [
                  _buildEditableTile(
                      "Name", studentData!["name"] ?? "", "name"),
                  _buildEditableTile(
                      "Email",
                      studentData!["email"] ?? user!.email ?? "",
                      "email"),
                  _buildEditableTile("Password", "********", "password"),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text("Logout"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete),
                    label: const Text("Delete Account"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEditableTile(String title, String value, String field) {
    return ListTile(
      title: Text("$title: $value"),
      trailing: IconButton(
        icon: const Icon(Icons.edit, color: Colors.blueAccent),
        onPressed: () => _updateField(field, value),
      ),
    );
  }
}
