import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/services/sop_warning_service.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class AdminFlaggedAccountsScreen extends StatefulWidget {
  const AdminFlaggedAccountsScreen({super.key});

  @override
  State<AdminFlaggedAccountsScreen> createState() => _AdminFlaggedAccountsScreenState();
}

class _AdminFlaggedAccountsScreenState extends State<AdminFlaggedAccountsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryGreen = const Color(0xFF347A5C);
  final SOPWarningService _warningService = SOPWarningService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Flagged Accounts & SOP Warnings",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryGreen,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Donors", icon: Icon(Icons.volunteer_activism_outlined, size: 20)),
            Tab(text: "Riders", icon: Icon(Icons.two_wheeler_outlined, size: 20)),
            Tab(text: "Beneficiaries", icon: Icon(Icons.people_outline, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserRoleList("donor"),
          _buildUserRoleList("volunteer"), // Covers Riders/Volunteers
          _buildUserRoleList("beneficiary"),
        ],
      ),
    );
  }

  Widget _buildUserRoleList(String roleQuery) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .where('role', isEqualTo: roleQuery)
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
                Icon(Icons.shield_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  "No $roleQuery accounts found",
                  style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        // Show flagged users first, or all users in this role tab
        List<QueryDocumentSnapshot> users = snapshot.data!.docs;
        users.sort((a, b) {
          Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
          Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;
          int warningsA = (dataA['warningCount'] ?? 0) as int;
          int warningsB = (dataB['warningCount'] ?? 0) as int;
          return warningsB.compareTo(warningsA);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            var doc = users[index];
            var data = doc.data() as Map<String, dynamic>;
            String uid = doc.id;

            String name = data['firstName'] ?? data['name'] ?? data['organizationName'] ?? 'User';
            if (data['lastName'] != null && data['lastName'].toString().isNotEmpty) {
              name = "$name ${data['lastName']}";
            }
            String email = data['email'] ?? 'No Email';
            String phone = data['phone'] ?? data['phoneNumber'] ?? 'No Phone';

            int warningCount = (data['warningCount'] ?? 0) as int;
            bool isFlagged = data['isFlagged'] == true;
            String status = (data['status'] ?? 'active').toString().toLowerCase();
            String flaggedReason = data['flaggedReason'] ?? 'SOP Compliance Review';

            Color statusColor = status == 'banned'
                ? Colors.red
                : status == 'under_review'
                    ? Colors.orange
                    : isFlagged
                        ? Colors.amber.shade800
                        : Colors.green;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isFlagged ? statusColor.withOpacity(0.5) : Colors.grey.shade200,
                  width: isFlagged ? 1.5 : 1,
                ),
              ),
              elevation: isFlagged ? 2 : 0.5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$email | $phone",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),

                        // Warning Badge & Status Tag
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            WarningBadgeWidget(
                              warningCount: warningCount,
                              isFlagged: isFlagged,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status.toUpperCase().replaceAll('_', ' '),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (isFlagged || warningCount > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Flag Reason: $flaggedReason",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),

                    // Admin Action Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_alert_outlined, size: 16),
                          label: const Text("Issue Warning", style: TextStyle(fontSize: 12)),
                          onPressed: () => _showIssueWarningDialog(uid, name, roleQuery),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryGreen,
                            side: BorderSide(color: primaryGreen),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.send_outlined, size: 16),
                          label: const Text("Send SOP Alert", style: TextStyle(fontSize: 12)),
                          onPressed: () => _sendSOPAlertNotification(uid, data),
                        ),
                        if (isFlagged || warningCount > 0)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                              side: BorderSide(color: Colors.green.shade700),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                            label: const Text("Clear Flag", style: TextStyle(fontSize: 12)),
                            onPressed: () => _clearUserFlags(uid, name),
                          ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.block_outlined, size: 16),
                          label: const Text("Ban Account", style: TextStyle(fontSize: 12)),
                          onPressed: () => _showBanDialog(uid, name),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showIssueWarningDialog(String uid, String name, String role) {
    TextEditingController reasonController = TextEditingController();
    List<String> sopOptions = [
      "Timely Pickup & Delivery SOP",
      "Food Quality & Hygiene SOP",
      "Authentic Image Upload SOP",
      "Dual OTP Verification SOP",
      "Beneficiary Daily Limit SOP",
      "Respectful Communication SOP"
    ];

    String selectedSop = sopOptions.first;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Issue Warning to $name"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select SOP Violated:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedSop,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: sopOptions.map((sop) {
                      return DropdownMenuItem(value: sop, child: Text(sop, style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedSop = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text("Warning Explanation / Details:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: "E.g., Repeated late pickups without prior notice...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                onPressed: () async {
                  String reason = reasonController.text.trim();
                  if (reason.isEmpty) return;
                  Navigator.pop(dialogCtx);

                  bool success = await _warningService.issueWarning(
                    uid: uid,
                    reason: reason,
                    sopsViolated: [selectedSop],
                    issuedBy: "Admin Portal",
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? "Warning issued successfully to $name!" : "Failed to issue warning.",
                        ),
                        backgroundColor: success ? primaryGreen : Colors.red,
                      ),
                    );
                  }
                },
                child: const Text("Confirm Warning", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendSOPAlertNotification(String uid, Map<String, dynamic> data) async {
    String fcmToken = data['fcmToken'] ?? '';
    String name = data['firstName'] ?? 'User';

    await _warningService.sendSOPWarningNotification(
      uid: uid,
      targetFcmToken: fcmToken,
      title: "SOP Guidelines Reminder",
      message: "Hello $name, please ensure compliance with Khair-e-Kaseer food recovery SOPs to keep your account active.",
      sopName: "Platform Compliance SOP",
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("SOP Warning Notification sent to $name."),
          backgroundColor: primaryGreen,
        ),
      );
    }
  }

  Future<void> _clearUserFlags(String uid, String name) async {
    bool success = await _warningService.clearFlags(uid: uid, resetWarnings: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Flags & warning count cleared for $name!" : "Failed to clear flags."),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showBanDialog(String uid, String name) {
    TextEditingController banReasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text("Ban Account - $name"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Reason for Permanent Account Ban:"),
            const SizedBox(height: 8),
            TextField(
              controller: banReasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Enter explanation for banning account...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              String reason = banReasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dialogCtx);

              bool success = await _warningService.updateAccountStatus(
                uid: uid,
                newStatus: "banned",
                reason: reason,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? "$name account has been banned." : "Failed to ban account."),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Confirm Permanent Ban", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
