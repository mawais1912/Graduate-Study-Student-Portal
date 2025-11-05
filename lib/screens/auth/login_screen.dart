import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController(); // Email OR Registration Number
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _addNotification(String uid, String message, bool success) async {
    await FirebaseFirestore.instance
        .collection("students")
        .doc(uid)
        .collection("notifications")
        .add({
      "message": message,
      "success": success,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      String input = _idController.text.trim();
      String email;
      String? uid;

      if (input.contains('@')) {
        // 🔹 If input is email
        email = input;
      } else {
        // 🔹 If input is registration number → fetch email from Firestore
        final snapshot = await FirebaseFirestore.instance
            .collection("students")
            .where("registrationNumber", isEqualTo: input)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          throw FirebaseAuthException(
            code: "user-not-found",
            message: "No student found with this registration number",
          );
        }
        email = snapshot.docs.first["email"];
        uid = snapshot.docs.first.id;
      }

      // 🔹 Login with resolved email + password
      UserCredential cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      uid = cred.user?.uid ?? uid;

      // 🔹 Add success notification
      if (uid != null) {
        await _addNotification(uid, "Login successful ✅", true);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Login Successful")),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      // 🔹 Add failure notification if user exists
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _addNotification(uid, "Login failed: ${e.message}", false);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ ${e.message}")),
      );
    } catch (e) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _addNotification(uid, "Login failed: $e", false);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Login"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: "Email or Registration Number",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.isEmpty)
                        ? "Enter email or reg. no."
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.length < 6)
                        ? "Enter min 6 chars"
                        : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                      onPressed: _login,
                      child: const Text(
                        "Login",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/forget'),
                    child: const Text("Forgot Password?"),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don’t have an account? "),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/signup'),
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    ],
                  ),
                  const Text ("If you are new use your email to login"),
                  const SizedBox(height: 50),
                  const Text ("Created By Awais Khan"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
