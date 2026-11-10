import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:khair_e_kaseer/screens/welcome_screen.dart';
import 'package:khair_e_kaseer/screens/email_verification_screen.dart';
import 'package:khair_e_kaseer/screens/volunteer/volunteer_dashboard_screen.dart';
import 'package:khair_e_kaseer/screens/beneficiary/beneficiary_dashboard_screen.dart';
import 'package:khair_e_kaseer/screens/onboarding/beneficiary_verification_screen.dart';
import 'package:khair_e_kaseer/screens/onboarding/ngo_verification_screen.dart';
import 'package:khair_e_kaseer/screens/onboarding/volunteer_verification_screen.dart';
import 'package:khair_e_kaseer/screens/onboarding/pending_verification_screen.dart';
import 'package:khair_e_kaseer/screens/donor/donor_main_navigation_screen.dart';
import 'package:khair_e_kaseer/screens/admin/admin_dashboard_screen.dart';

import '../beneficiary/beneficiary_main_navigation_screen.dart';
import '../volunteer/volunteer_main_navigation_screen.dart';
import 'package:khair_e_kaseer/services/notification_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF347A5C);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator(color: primaryGreen)),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const WelcomeScreen();
        }

        // Save/Sync FCM Device Token upon successful authentication
        NotificationService().saveDeviceToken();

        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, prefsSnapshot) {
            if (prefsSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                body: Center(child: CircularProgressIndicator(color: primaryGreen)),
              );
            }

            final prefs = prefsSnapshot.data;
            final bool isAwaitingOtp = prefs?.getBool('is_awaiting_verification') ?? false;
            final String? unverifiedEmail = prefs?.getString('unverified_email');

            if (isAwaitingOtp && unverifiedEmail != null) {
              return EmailVerificationScreen(email: unverifiedEmail);
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(child: CircularProgressIndicator(color: primaryGreen)),
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  if (user.email != null && user.email!.toLowerCase().contains('admin')) {
                    return const AdminDashboardScreen();
                  }
                  return const WelcomeScreen();
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                final String role = (userData['role'] ?? '').toString().trim().toLowerCase();
                final bool isVerified = userData['isVerified'] == true;
                final String status = (userData['verificationStatus'] ?? 'unsubmitted')
                    .toString()
                    .trim()
                    .toLowerCase();

                // 1. Admin users route directly
                if (role == 'admin') {
                  return const AdminDashboardScreen();
                }

                // 2. Donor users route directly
                if (role == 'donor') {
                  return const DonorMainNavigationScreen();
                }

                // 3. Verified users (Volunteer/Beneficiary) go to main dashboards
                if (isVerified) {
                  if (role == 'volunteer') {
                    return const VolunteerMainNavigationScreen();
                  } else {
                    return const BeneficiaryMainNavigationScreen();
                  }
                }

                // 4. Users awaiting admin approval or rejected
                if (status == 'pending' || status == 'rejected') {
                  return const PendingVerificationScreen();
                }

                // 5. Unverified / Unsubmitted users must complete document verification screen first
                if (role == 'volunteer') {
                  return const VolunteerVerificationScreen();
                } else if (role == 'ngo') {
                  return const NgoVerificationScreen();
                } else {
                  return const BeneficiaryVerificationScreen();
                }
              },
            );
          },
        );
      },
    );
  }
}