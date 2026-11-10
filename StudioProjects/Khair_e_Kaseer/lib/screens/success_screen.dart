import 'package:flutter/material.dart';
import 'package:khair_e_kaseer/screens/onboarding/auth_wrapper.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  bool _isRedirecting = false;
  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);

  void _handleGetStarted() {
    setState(() => _isRedirecting = true);

    // Pass control to AuthWrapper to evaluate verification & role
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/congrats_icon.png',
                height: 200,
              ),
              const SizedBox(height: 30),
              const Text(
                'Congratulations !',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 15),
              const Text(
                'Your journey to sharing and saving food begins now.\nLet’s make an impact!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 50),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isRedirecting ? null : _handleGetStarted,
                  child: _isRedirecting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}