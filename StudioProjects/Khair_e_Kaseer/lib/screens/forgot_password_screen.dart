import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int selectedOption = 0; // 0 = Email, 1 = Phone
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (selectedOption == 1) {
      CustomSnackBar.showWarning(context, "Phone recovery is currently unavailable. Please use Email.");
      return;
    }

    if (email.isEmpty) {
      CustomSnackBar.showError(context, "Please enter your registered email address.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        CustomSnackBar.showSuccess(context, "Password reset email sent! Check your inbox.");
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, e.message ?? "An error occurred");
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, "Error: ${e.toString()}");
      }
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
              const SizedBox(height: 30),
              const Text(
                'Forgot Password',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose an option to receive a password recovery link.',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              _buildOptionCard(
                index: 0,
                title: 'Send to your Email',
                icon: Icons.email_outlined,
              ),

              const SizedBox(height: 15),

              _buildOptionCard(
                index: 1,
                title: 'Send to your Phone Number',
                icon: Icons.phone_outlined,
              ),

              const SizedBox(height: 30),

              if (selectedOption == 0) ...[
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Email Address',
                  hintText: 'Enter your registered email',
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF347A5C)),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],

              const SizedBox(height: 40),

              PrimaryActionButton(
                label: 'Continue',
                isLoading: _isLoading,
                onPressed: _resetPassword,
                height: 52,
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required int index,
    required String title,
    required IconData icon,
  }) {
    bool isSelected = selectedOption == index;

    return CustomCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(18),
      borderColor: isSelected ? primaryGreen : Colors.transparent,
      backgroundColor: isSelected ? Colors.white : const Color(0xFFF2F2F2),
      onTap: () => setState(() => selectedOption = index),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? primaryGreen : Colors.grey,
            size: 26,
          ),
          const SizedBox(width: 18),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.black : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
