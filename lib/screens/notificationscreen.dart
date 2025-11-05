import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("❌ Not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Notifications"),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("students")
            .doc(user!.uid)
            .collection("notifications")
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("📭 No notifications yet"),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: Icon(
                    data["success"] == true
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color:
                    data["success"] == true ? Colors.green : Colors.redAccent,
                  ),
                  title: Text(data["message"] ?? "No message"),
                  subtitle: Text(
                    (data["timestamp"] != null)
                        ? (data["timestamp"] as Timestamp)
                        .toDate()
                        .toString()
                        : "No time",
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
