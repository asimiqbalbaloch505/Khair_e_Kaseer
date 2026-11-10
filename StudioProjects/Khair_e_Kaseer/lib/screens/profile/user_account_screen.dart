import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:khair_e_kaseer/screens/profile/beneficiary_account_view.dart';
import 'package:khair_e_kaseer/screens/profile/donor_account_view.dart';
import 'package:khair_e_kaseer/screens/profile/rider_account_view.dart';
import 'package:khair_e_kaseer/screens/profile/edit_profile_dialog.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class UserAccountScreen extends StatefulWidget {
  const UserAccountScreen({super.key});

  @override
  State<UserAccountScreen> createState() => _UserAccountScreenState();
}

class _UserAccountScreenState extends State<UserAccountScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color primaryGreen = const Color(0xFF347A5C);

  void _openEditProfileModal(Map<String, dynamic> userData) {
    if (currentUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EditProfileDialog(
        uid: currentUser!.uid,
        userData: userData,
      ),
    );
  }

  Future<void> _handleLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sign Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      debugPrint("Error logging out: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Account")),
        body: const Center(child: Text("User not authenticated.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "My Account & Settings",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: "Sign Out",
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .doc(currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryGreen));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                "Profile record not found.",
                style: TextStyle(color: Colors.grey.shade700),
              ),
            );
          }

          Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          String firstName = userData['firstName'] ?? userData['name'] ?? 'User';
          String lastName = userData['lastName'] ?? '';
          String fullName = lastName.isNotEmpty ? "$firstName $lastName" : firstName;
          String email = userData['email'] ?? currentUser?.email ?? 'No email';
          String phone = userData['phone'] ?? userData['phoneNumber'] ?? 'No phone';
          String role = (userData['role'] ?? 'beneficiary').toString().trim().toLowerCase();
          String photoUrl = userData['photoUrl'] ?? userData['profilePicture'] ?? '';

          return Column(
            children: [
              // Common Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          photoUrl: photoUrl,
                          name: fullName,
                          radius: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$email | $phone",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: primaryGreen.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SecondaryButton(
                          label: "Edit",
                          icon: Icons.edit,
                          height: 36,
                          onPressed: () => _openEditProfileModal(userData),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Role-matched View Content
              Expanded(
                child: _buildRoleView(role, currentUser!.uid, userData),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleView(String role, String uid, Map<String, dynamic> userData) {
    switch (role) {
      case 'donor':
      case 'ngo':
        return DonorAccountView(
          uid: uid,
          userData: userData,
          onEditProfile: () => _openEditProfileModal(userData),
        );

      case 'volunteer':
      case 'rider':
        return RiderAccountView(
          uid: uid,
          userData: userData,
          onEditProfile: () => _openEditProfileModal(userData),
        );

      case 'beneficiary':
      default:
        return BeneficiaryAccountView(
          uid: uid,
          userData: userData,
          onEditProfile: () => _openEditProfileModal(userData),
        );
    }
  }
}
