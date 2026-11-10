import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/onboarding/beneficiary_verification_screen.dart';
import 'package:khair_e_kaseer/screens/onboarding/volunteer_verification_screen.dart';
import 'package:khair_e_kaseer/screens/onboarding/ngo_verification_screen.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class PendingVerificationScreen extends StatelessWidget {
  const PendingVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF347A5C);
    final Color bgCream = const Color(0xFFFBFBF4);
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: bgCream,
        appBar: const UnverifiedAppBar(
          title: "Verification Review",
          statusBadge: "Under Review",
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(currentUserId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primaryGreen));
            }

            String rejectionReason = '';
            String status = 'pending';
            String role = 'beneficiary';

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              status = (data['verificationStatus'] ?? 'pending').toString().toLowerCase();
              rejectionReason = data['rejectionReason'] ?? '';
              role = (data['role'] ?? 'beneficiary').toString().toLowerCase();
            }

            bool isRejected = status == 'rejected';

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isRejected ? Colors.red.shade50 : primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
                        size: 70,
                        color: isRejected ? Colors.redAccent : primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      isRejected ? "Verification Required Action" : "Verification Under Review",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isRejected
                          ? "Your verification request requires modifications before approval. Please review the admin remarks below."
                          : "Your documents have been submitted to our administration team. We are verifying your profile to maintain platform safety and prevent abuse.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.4),
                    ),
                    if (isRejected && rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Reason for Rejection:",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rejectionReason,
                              style: TextStyle(color: Colors.red.shade900, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 35),
                    if (isRejected) ...[
                      PrimaryActionButton(
                        label: "Re-upload Documents",
                        icon: Icons.refresh,
                        onPressed: () {
                          Widget targetScreen;
                          if (role == 'volunteer') {
                            targetScreen = const VolunteerVerificationScreen();
                          } else if (role == 'ngo') {
                            targetScreen = const NgoVerificationScreen();
                          } else {
                            targetScreen = const BeneficiaryVerificationScreen();
                          }

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => targetScreen),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
