import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/services/sop_warning_service.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class AdminManualReviewScreen extends StatefulWidget {
  const AdminManualReviewScreen({super.key});

  @override
  State<AdminManualReviewScreen> createState() => _AdminManualReviewScreenState();
}

class _AdminManualReviewScreenState extends State<AdminManualReviewScreen> {
  final Color primaryGreen = const Color(0xFF347A5C);
  final SOPWarningService _warningService = SOPWarningService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "High-Risk Accounts (Manual Review)",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryGreen));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_outlined, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    "No accounts pending manual review",
                    style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          // Filter for accounts with >2 flags or status == 'under_review' or isFlagged
          List<QueryDocumentSnapshot> reviewDocs = snapshot.data!.docs.where((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            int warningCount = (data['warningCount'] ?? 0) as int;
            String status = (data['status'] ?? '').toString().toLowerCase();
            bool isFlagged = data['isFlagged'] == true;

            return warningCount >= 2 || status == 'under_review' || (isFlagged && warningCount > 0);
          }).toList();

          if (reviewDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: primaryGreen.withOpacity(0.6)),
                  const SizedBox(height: 12),
                  const Text(
                    "All high-risk accounts reviewed!",
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text("No users with >2 warning flags currently.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reviewDocs.length,
            itemBuilder: (context, index) {
              var doc = reviewDocs[index];
              var data = doc.data() as Map<String, dynamic>;
              String uid = doc.id;

              String name = data['firstName'] ?? data['name'] ?? data['organizationName'] ?? 'User';
              if (data['lastName'] != null && data['lastName'].toString().isNotEmpty) {
                name = "$name ${data['lastName']}";
              }
              String role = (data['role'] ?? 'User').toString().toUpperCase();
              String email = data['email'] ?? 'No Email';
              String phone = data['phone'] ?? data['phoneNumber'] ?? 'No Phone';
              int warningCount = (data['warningCount'] ?? 0) as int;
              List warningHistory = (data['warningHistory'] as List?) ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.shade300, width: 1.5),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
                  ),
                  title: Text(
                    "$name ($role)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    "$email\nWarning Count: $warningCount | Status: UNDER REVIEW",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 4),

                          // Contact Details
                          Text("Phone: $phone", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),

                          // Warning History Audit Breakdown
                          const Text("Warning History Audit Trail:",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),

                          if (warningHistory.isEmpty)
                            const Text("No detailed warning history logs recorded.",
                                style: TextStyle(fontSize: 12, color: Colors.grey))
                          else
                            Column(
                              children: warningHistory.map<Widget>((w) {
                                Map wMap = w is Map ? w : {};
                                String reason = wMap['reason'] ?? 'No reason';
                                List sops = (wMap['sopsViolated'] as List?) ?? [];
                                String ts = wMap['timestamp'] ?? '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade100),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.report_problem_outlined, size: 16, color: Colors.red.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "SOP: ${sops.join(', ')}",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.red.shade900),
                                            ),
                                            const SizedBox(height: 2),
                                            Text("Reason: $reason", style: const TextStyle(fontSize: 12)),
                                            if (ts.isNotEmpty)
                                              Text("Time: $ts",
                                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),

                          const SizedBox(height: 14),

                          // Linked Violation Records from /sop_violations
                          const Text("Linked Gemini & Proof Audit Logs:",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),

                          FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('sop_violations')
                                .where('uid', isEqualTo: uid)
                                .get(),
                            builder: (context, violSnap) {
                              if (violSnap.connectionState == ConnectionState.waiting) {
                                return const Text("Loading audit logs...", style: TextStyle(fontSize: 12));
                              }
                              if (!violSnap.hasData || violSnap.data!.docs.isEmpty) {
                                return const Text("No specific proof logs recorded in system.",
                                    style: TextStyle(fontSize: 12, color: Colors.grey));
                              }

                              return Column(
                                children: violSnap.data!.docs.map((vDoc) {
                                  var vData = vDoc.data() as Map<String, dynamic>;
                                  String type = vData['violationType'] ?? 'Violation';
                                  String proof = vData['proofDetails'] ?? '';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.folder_open_outlined, size: 14, color: Colors.blueGrey),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text("$type: $proof", style: const TextStyle(fontSize: 11)),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),

                          // Action Buttons
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PrimaryActionButton(
                                label: "Approve & Reset Flags",
                                icon: Icons.check_circle_outline,
                                onPressed: () => _approveAndResetAccount(uid, name),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: SecondaryButton(
                                      label: "Suspend (7 Days)",
                                      icon: Icons.timer_outlined,
                                      color: Colors.orange.shade900,
                                      onPressed: () => _suspendAccount(uid, name, 7),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DangerButton(
                                      label: "Permanent Ban",
                                      icon: Icons.block,
                                      onPressed: () => _permanentBanAccount(uid, name),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _approveAndResetAccount(String uid, String name) async {
    bool success = await _warningService.clearFlags(uid: uid, resetWarnings: true, clearedBy: "Manual Review Portal");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Flags cleared & $name account approved!" : "Failed to reset flags."),
          backgroundColor: success ? primaryGreen : Colors.red,
        ),
      );
    }
  }

  void _suspendAccount(String uid, String name, int days) async {
    bool success = await _warningService.updateAccountStatus(
      uid: uid,
      newStatus: "suspended",
      reason: "Manual review determination: Temporary $days-day suspension.",
      suspendDays: days,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "$name suspended for $days days." : "Failed to suspend account."),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  void _permanentBanAccount(String uid, String name) async {
    bool success = await _warningService.updateAccountStatus(
      uid: uid,
      newStatus: "banned",
      reason: "Manual review determination: Multiple unfulfilled SOP warnings.",
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "$name has been permanently banned." : "Failed to ban account."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
