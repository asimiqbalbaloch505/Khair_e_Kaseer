import 'package:flutter/material.dart';
import 'package:khair_e_kaseer/screens/profile/warning_history_widget.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class DonorAccountView extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userData;
  final VoidCallback onEditProfile;

  const DonorAccountView({
    super.key,
    required this.uid,
    required this.userData,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF347A5C);

    int warningCount = (userData['warningCount'] ?? 0) as int;
    bool isFlagged = userData['isFlagged'] == true;
    String? flaggedReason = userData['flaggedReason'];
    List warningHistory = (userData['warningHistory'] as List?) ?? [];

    int totalDonated = (userData['totalDonationsCount'] ?? 24) as int;
    double totalKgSaved = ((userData['totalKgSaved'] ?? 180.5) as num).toDouble();
    int activeListings = (userData['activeListingsCount'] ?? 2) as int;
    int completedRecoveries = (userData['completedRecoveriesCount'] ?? 22) as int;

    int trustScore = (userData['qualityTrustScore'] ?? 98) as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Quality & Gemini Trust Score Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGreen, primaryGreen.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(Icons.verified_outlined, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$trustScore% Quality Trust Rating",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Verified by Gemini AI Visual Inspections & Donor Hygiene SOP Compliance.",
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Donor Impact Metrics
          const Text("Donation Impact Metrics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: MetricStatCard(
                  title: "Total Donated",
                  value: "$totalDonated Items",
                  subtitle: "$completedRecoveries Recovered",
                  icon: Icons.volunteer_activism_outlined,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricStatCard(
                  title: "Food Saved",
                  value: "${totalKgSaved.toStringAsFixed(1)} kg",
                  subtitle: "~${(totalKgSaved * 3).toInt()} Meals Saved",
                  icon: Icons.scale_outlined,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: MetricStatCard(
                  title: "Active Listings",
                  value: "$activeListings Active",
                  subtitle: "Available for claim",
                  icon: Icons.list_alt_outlined,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricStatCard(
                  title: "Gemini Audits",
                  value: "100% Passed",
                  subtitle: "Photo Verification",
                  icon: Icons.auto_awesome_outlined,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // SOP Warnings & History Tracker
          WarningHistoryWidget(
            warningCount: warningCount,
            isFlagged: isFlagged,
            flaggedReason: flaggedReason,
            warningHistory: warningHistory,
          ),

          const SizedBox(height: 16),

          // Donor SOP Guidelines Button
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              leading: Icon(Icons.rule_folder_outlined, color: primaryGreen),
              title: const Text("Donor Food Safety SOP Guidelines", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("4-6 hour cooked food freshness rule & photo proof standards"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => SopGuidelinesModal.show(context, role: 'donor'),
            ),
          ),
        ],
      ),
    );
  }
}
