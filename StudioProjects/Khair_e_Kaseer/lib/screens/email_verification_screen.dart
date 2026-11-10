import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/login_form_screen.dart'; // Adjust path to your Login screen if different
import 'package:khair_e_kaseer/screens/success_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _timer;
  Timer? _cooldownTimer;

  bool _isCheckingStatus = false;
  bool _isResending = false;
  int _resendCooldown = 0;

  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);

  @override
  void initState() {
    super.initState();
    _saveVerificationState();

    // Periodically reload user state to check if they clicked the link
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified());
  }

  /// Persists verification state so app returns here if killed/reopened
  Future<void> _saveVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_awaiting_verification', true);
    await prefs.setString('unverified_email', widget.email);
  }

  /// Clears local verification flags upon success or cancellation
  Future<void> _clearVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_awaiting_verification');
    await prefs.remove('unverified_email');
  }

  /// Handles Back Button action: signs out user and navigates to Login/Signup screen
  Future<void> _handleBackAndChangeEmail() async {
    _timer?.cancel();
    _cooldownTimer?.cancel();

    await _clearVerificationState();
    await _auth.signOut();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginFormScreen()), // Change to your Login or SignUp screen if needed
            (route) => false,
      );
    }
  }

  /// Dispatches the built-in Firebase link verification email
  Future<void> _sendVerificationEmail() async {
    if (_resendCooldown > 0) return;

    setState(() => _isResending = true);
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _showSnackBar("Verification link sent to ${widget.email}", Colors.green);
        _startCooldownTimer();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        _showSnackBar("Too many requests. Please wait before requesting another email.", Colors.orangeAccent);
        _startCooldownTimer(duration: 60);
      } else {
        _showSnackBar("Error sending email: ${e.message ?? e.toString()}", Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar("Error sending email: ${e.toString()}", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldownTimer({int duration = 30}) {
    setState(() => _resendCooldown = duration);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  /// Checks if the user has clicked the verification link
  Future<void> _checkEmailVerified({bool showLoader = false}) async {
    if (showLoader) setState(() => _isCheckingStatus = true);

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.reload(); // Refresh user session
        user = _auth.currentUser;

        if (user != null && user.emailVerified) {
          _timer?.cancel();

          // Fetch user role and update Firestore state
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            String role = (userDoc['role'] ?? '').toString().toLowerCase();
            bool isDonor = role == 'donor';

            await FirebaseFirestore.instance.collection('Users').doc(user.uid).update({
              "isVerified": isDonor,
              "verificationStatus": isDonor ? "approved" : "unsubmitted",
            });
          }

          await _clearVerificationState();

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SuccessScreen()),
                  (route) => false,
            );
          }
        } else if (showLoader) {
          _showSnackBar("Email not verified yet. Please check your inbox and click the link.", Colors.orangeAccent);
        }
      }
    } catch (e) {
      if (showLoader) {
        _showSnackBar("Verification check error: ${e.toString()}", Colors.redAccent);
      }
    } finally {
      if (mounted && showLoader) setState(() => _isCheckingStatus = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackAndChangeEmail();
        }
      },
      child: Scaffold(
        backgroundColor: bgCream,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Row(
                  children: [
                    IconButton(
                      onPressed: _handleBackAndChangeEmail,
                      icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _handleBackAndChangeEmail,
                      child: const Text(
                        "Change Email",
                        style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Verify Your Email', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Text(
                  'We have sent a verification link to:\n${widget.email}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 40),

                // Visual Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.mark_email_unread_outlined, size: 70, color: primaryGreen),
                      const SizedBox(height: 15),
                      const Text(
                        "Check Your Inbox",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Tap the verification link in the email to automatically complete your account setup.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Resend Link Option
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Didn't receive the email? "),
                    GestureDetector(
                      onTap: (_isResending || _resendCooldown > 0) ? null : _sendVerificationEmail,
                      child: Text(
                        _isResending
                            ? "Sending..."
                            : (_resendCooldown > 0 ? "Resend in ${_resendCooldown}s" : "Resend Link"),
                        style: TextStyle(
                          color: (_isResending || _resendCooldown > 0) ? Colors.grey : primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Manual Check Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isCheckingStatus ? null : () => _checkEmailVerified(showLoader: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isCheckingStatus
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "I've Verified My Email",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}