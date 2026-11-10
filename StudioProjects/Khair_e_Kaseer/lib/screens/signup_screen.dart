import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/email_verification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String? _selectedRole;
  final List<String> _roles = ['Donor', 'Beneficiary', 'Volunteer', 'NGO'];
  bool _isLoading = false;

  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);

  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
  }

  Future<void> _registerUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        _selectedRole == null ||
        _firstNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      CustomSnackBar.showError(context, "Please fill all fields and select your Role.");
      return;
    }

    if (!_isValidEmail(email)) {
      CustomSnackBar.showError(context, "Please enter a valid email address.");
      return;
    }

    if (password != _confirmPasswordController.text.trim()) {
      CustomSnackBar.showError(context, "Passwords do not match!");
      return;
    }

    if (password.length < 6) {
      CustomSnackBar.showError(context, "Password must be at least 6 characters long.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        try {
          final bool isDonor = _selectedRole?.toLowerCase() == 'donor';

          await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
            "userId": user.uid,
            "firstName": _firstNameController.text.trim(),
            "lastName": _lastNameController.text.trim(),
            "email": email,
            "phone": _phoneController.text.trim(),
            "role": _selectedRole,
            "isVerified": isDonor,
            "verificationStatus": isDonor ? "approved" : "unsubmitted",
            "createdAt": DateTime.now().millisecondsSinceEpoch,
          });

          await user.sendEmailVerification();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_awaiting_verification', true);
          await prefs.setString('unverified_email', email);

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => EmailVerificationScreen(email: email),
              ),
              (route) => false,
            );
          }
        } catch (firestoreError) {
          await user.delete();
          if (mounted) CustomSnackBar.showError(context, "Failed to save profile. Please try signing up again.");
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) CustomSnackBar.showError(context, e.message ?? "Authentication Failed");
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, "Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.black, size: 30),
              ),
              const SizedBox(height: 20),
              const Text('Sign Up', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('Sign up and start sharing meals today.', style: TextStyle(fontSize: 15, color: Colors.grey)),
              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _firstNameController,
                      labelText: 'First Name',
                      hintText: 'First Name',
                      prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF347A5C)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomTextField(
                      controller: _lastNameController,
                      labelText: 'Last Name',
                      hintText: 'Last Name',
                      prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF347A5C)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              CustomTextField(
                controller: _emailController,
                labelText: 'Email Address',
                hintText: 'Your Email',
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF347A5C)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),

              CustomTextField(
                controller: _phoneController,
                labelText: 'Phone Number',
                hintText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF347A5C)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 15),

              CustomDropdown<String>(
                value: _selectedRole,
                labelText: 'Select Your Role',
                hintText: 'Choose Role',
                prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF347A5C)),
                items: _roles.map((String role) {
                  return DropdownMenuItem<String>(value: role, child: Text(role));
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedRole = newValue);
                },
              ),
              const SizedBox(height: 15),

              CustomTextField(
                controller: _passwordController,
                labelText: 'Password',
                hintText: 'Your Password',
                isPassword: true,
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF347A5C)),
              ),
              const SizedBox(height: 15),

              CustomTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirm Password',
                hintText: 'Confirm Password',
                isPassword: true,
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF347A5C)),
              ),

              const SizedBox(height: 30),

              PrimaryActionButton(
                label: 'Register',
                isLoading: _isLoading,
                onPressed: _registerUser,
                height: 52,
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }
}
