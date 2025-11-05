import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _regNoController = TextEditingController();
  final _cnicController = TextEditingController();

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

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // 🔹 Check if registration number already exists
      final regSnapshot = await FirebaseFirestore.instance
          .collection("students")
          .where("registrationNumber", isEqualTo: _regNoController.text.trim())
          .limit(1)
          .get();

      if (regSnapshot.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: "regno-exists",
          message: "This registration number is already taken",
        );
      }

      // 🔹 Check if CNIC number already exists
      final cnicSnapshot = await FirebaseFirestore.instance
          .collection("students")
          .where("cnicnumber", isEqualTo: _cnicController.text.trim())
          .limit(1)
          .get();

      if (cnicSnapshot.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: "CNIC Exit",
          message: "This CNIC number is already taken",
        );
      }

      // 🔹 Create Firebase Auth user
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 🔹 Save student data in Firestore
      await FirebaseFirestore.instance
          .collection("students")
          .doc(_cnicController.text.trim())
          .set({
        "uid": cred.user!.uid,  // still keep UID if needed
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "registrationNumber": _regNoController.text.trim(),
        "cnicnumber": _cnicController.text.trim(),
        "createdAt": DateTime.now(),
      });

      // 🔹 Add success notification
      await _addNotification(
        cred.user!.uid,
        "Signup successful 🎉",
        true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Signup Successful")),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      // 🔹 Add failure notification if user already exists or other error
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _addNotification(uid, "Signup failed: ${e.message}", false);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ ${e.message}")),
      );
    } catch (e) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _addNotification(uid, "Signup failed: $e", false);
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
        title: const Text("Student Sign Up"),
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
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Name",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.isEmpty) ? "Enter your name" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _regNoController,
                    decoration: const InputDecoration(
                      labelText: "Registration Number",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? "Enter your registration number"
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cnicController,
                    decoration: const InputDecoration(
                      labelText: "CNIC Number",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || !v.isEmpty && v.length != 13)
                        ? "Enter valid CNIC number"
                        : null,),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? "Enter valid email"
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
                    validator: (v) => (v == null || v.length < 6)
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
                      onPressed: _signup,
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? "),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),

                        ),

                      ),
                      // const Text("If you are new then in Ag Number field put 00000"),
                    ],
                  ),
                  const Text("If you are new then in Ag Number field put your cnic"),
                  const SizedBox(height: 30),
                  const Text("Created By Awais khan"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
