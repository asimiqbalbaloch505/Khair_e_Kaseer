import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/common/account_screen.dart';
import 'package:khair_e_kaseer/screens/admin/admin_flagged_accounts_screen.dart';
import 'package:khair_e_kaseer/screens/admin/admin_sop_violations_screen.dart';
import 'package:khair_e_kaseer/screens/admin/admin_manual_review_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Color primaryGreen = const Color(0xFF347A5C);
  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Admin Portal",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.black, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountScreen()),
              );
            },
          ),
        ],
      ),
      body: _buildSelectedTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedNavIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.verified_user_outlined),
            label: "Verifications",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            label: "Accounts & Warnings",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rule_folder_outlined),
            label: "SOP Logs",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_outlined),
            label: "Manual Review",
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildPendingVerificationsTab();
      case 1:
        return const AdminFlaggedAccountsScreen();
      case 2:
        return const AdminSopViolationsScreen();
      case 3:
        return const AdminManualReviewScreen();
      default:
        return _buildPendingVerificationsTab();
    }
  }

  Widget _buildPendingVerificationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .where('verificationStatus', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryGreen));
        }

        List<QueryDocumentSnapshot> pendingUsers = snapshot.data?.docs ?? [];

        if (pendingUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  "No pending verifications",
                  style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingUsers.length,
          itemBuilder: (context, index) {
            var doc = pendingUsers[index];
            var data = doc.data() as Map<String, dynamic>;

            String name = data['firstName'] ?? data['name'] ?? data['organizationName'] ?? 'Unknown User';
            String role = (data['role'] ?? 'Beneficiary').toString().toUpperCase();
            String email = data['email'] ?? 'No Email';
            String phone = data['phone'] ?? data['phoneNumber'] ?? 'No Phone';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: primaryGreen.withOpacity(0.1),
                  child: Icon(Icons.badge_outlined, color: primaryGreen),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("$email\nRole: $role | Phone: $phone"),
                isThreeLine: true,
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showReviewDialog(doc.id, data),
                  child: const Text("Review"),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReviewDialog(String uid, Map<String, dynamic> data) {
    String name = data['firstName'] ?? data['name'] ?? data['organizationName'] ?? 'User';
    String role = (data['role'] ?? 'User').toString().toUpperCase();
    String userEmail = data['email'] ?? '';

    Map<String, dynamic> vData = data['verificationData'] is Map<String, dynamic>
        ? data['verificationData'] as Map<String, dynamic>
        : {};

    // Supporting NGO, Beneficiary, and Volunteer data fields
    String ngoName = vData['ngoName'] ?? '';
    String ngoRegNo = vData['ngoRegNumber'] ?? '';
    String vehicleRegNo = vData['vehicleRegistrationNumber'] ?? '';
    String vehicleType = vData['vehicleType'] ?? data['vehicleType'] ?? '';

    String applicantCnic = vData['cnic'] ??
        vData['representativeCnic'] ??
        vData['applicantCnic'] ??
        data['cnicNumber'] ??
        data['documentNumber'] ??
        'Not provided';

    String address = vData['officialAddress'] ?? vData['address'] ?? data['address'] ?? 'Not provided';

    String? certImage = vData['certificateImage'];
    String? cnicFront = vData['repCnicFront'] ?? vData['cnicFront'] ?? data['documentImage'] ?? data['proofImage'];
    String? cnicBack = vData['cnicBack'];
    String? proofDoc = vData['proofDoc'];

    // Volunteer images
    String? drivingLicense = vData['drivingLicense'];
    String? vehicleDoc = vData['vehicleDocument'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Review Application ($role)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Text("Applicant Name: $name", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (ngoName.isNotEmpty) Text("NGO Name: $ngoName"),
            if (ngoRegNo.isNotEmpty) Text("NGO Registration No: $ngoRegNo"),
            if (vehicleRegNo.isNotEmpty) Text("Vehicle Registration No: $vehicleRegNo"),
            if (vehicleType.isNotEmpty) Text("Vehicle Type: ${vehicleType.toUpperCase()}"),
            const SizedBox(height: 4),
            Text("CNIC / Rep CNIC: $applicantCnic"),
            if (address != 'Not provided') Text("Address: $address"),
            const SizedBox(height: 15),

            const Text("Uploaded Document Proofs:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (certImage != null && certImage.isNotEmpty) ...[
                      _buildImageCard("NGO Registration Certificate", certImage),
                      const SizedBox(height: 12),
                    ],
                    if (cnicFront != null && cnicFront.isNotEmpty) ...[
                      _buildImageCard("CNIC Front", cnicFront),
                      const SizedBox(height: 12),
                    ],
                    if (cnicBack != null && cnicBack.isNotEmpty) ...[
                      _buildImageCard("CNIC Back", cnicBack),
                      const SizedBox(height: 12),
                    ],
                    if (drivingLicense != null && drivingLicense.isNotEmpty) ...[
                      _buildImageCard("Driving License Photo", drivingLicense),
                      const SizedBox(height: 12),
                    ],
                    if (vehicleDoc != null && vehicleDoc.isNotEmpty) ...[
                      _buildImageCard("Vehicle Registration Document", vehicleDoc),
                      const SizedBox(height: 12),
                    ],
                    if (proofDoc != null && proofDoc.isNotEmpty) ...[
                      _buildImageCard("Additional Proof Document / Bill", proofDoc),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _promptRejectionReason(uid, userEmail, name),
                    child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _updateUserStatus(uid: uid, isApproved: true, email: userEmail, userName: name),
                    child: const Text("Approve User", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _promptRejectionReason(String uid, String email, String userName) {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Rejection Reason"),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Enter explanation (e.g. Blurry CNIC photo, invalid address...)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              String reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dialogCtx);
              _updateUserStatus(
                uid: uid,
                isApproved: false,
                email: email,
                userName: userName,
                rejectionReason: reason,
              );
            },
            child: const Text("Confirm Rejection", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(String title, String? base64Image) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Container(
            height: 180,
            width: double.infinity,
            alignment: Alignment.center,
            child: (base64Image != null && base64Image.isNotEmpty)
                ? ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Image.memory(
                base64Decode(base64Image),
                fit: BoxFit.contain,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text("Error rendering image"),
                ),
              ),
            )
                : const Center(
              child: Text("No image uploaded", style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserStatus({
    required String uid,
    required bool isApproved,
    required String email,
    required String userName,
    String rejectionReason = "",
  }) async {
    // 1. Pop bottom sheet modal first to avoid stale context issues
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // 2. Show loading feedback to admin
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Updating user status..."),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      DocumentReference userRef = FirebaseFirestore.instance.collection('Users').doc(uid);

      Map<String, dynamic> updateData = isApproved
          ? {
        'isVerified': true,
        'verificationStatus': 'approved',
        'rejectionReason': FieldValue.delete(),
      }
          : {
        'isVerified': false,
        'verificationStatus': 'rejected',
        'rejectionReason': rejectionReason,
      };

      // Direct Firestore document update
      await userRef.update(updateData);

      // Attempt to post email notification separately so mail rule failures don't block the verification update
      if (email.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('mail').add({
            'to': [email],
            'message': {
              'subject': isApproved
                  ? 'Account Verified - Khair-e-Kaseer'
                  : 'Verification Update - Khair-e-Kaseer',
              'html': isApproved
                  ? '<h3>Congratulations $userName!</h3><p>Your document verification for Khair-e-Kaseer has been approved. You can now access all services on the mobile app.</p>'
                  : '<h3>Hello $userName,</h3><p>Your verification request requires updates before approval.</p><p><b>Reason:</b> $rejectionReason</p><p>Please log back into the app to re-upload your verification details.</p>',
            },
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
        } catch (mailError) {
          debugPrint("Mail creation failed (check Firestore rules for 'mail' collection): $mailError");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApproved ? "User approved successfully!" : "User application rejected."),
            backgroundColor: isApproved ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating verification status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update status: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
