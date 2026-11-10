import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/profile/warning_history_widget.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class BeneficiaryAccountView extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userData;
  final VoidCallback onEditProfile;

  const BeneficiaryAccountView({
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

    Timestamp? lastOrderTs = userData['lastOrderAt'] as Timestamp?;
    bool hasRequestedToday = false;
    if (lastOrderTs != null) {
      DateTime lastDate = lastOrderTs.toDate();
      DateTime now = DateTime.now();
      if (lastDate.year == now.year && lastDate.month == now.month && lastDate.day == now.day) {
        hasRequestedToday = true;
      }
    }

    int totalMealsReceived = (userData['totalMealsReceived'] ?? 12) as int;
    int activeRequests = (userData['activeRequestsCount'] ?? 1) as int;
    int missedPickups = (userData['missedPickupsCount'] ?? 0) as int;
    int priorityScore = (100 - (missedPickups * 15)).clamp(40, 100);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily Quota Enforcement Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasRequestedToday ? Colors.amber.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasRequestedToday ? Colors.amber.shade300 : Colors.green.shade300,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasRequestedToday ? Colors.amber.shade100 : Colors.green.shade100,
                  child: Icon(
                    hasRequestedToday ? Icons.lock_clock_outlined : Icons.check_circle_outline,
                    color: hasRequestedToday ? Colors.amber.shade900 : primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasRequestedToday
                            ? "Daily Quota Reached (1/1 Today)"
                            : "Daily Quota Available (0/1 Today)",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: hasRequestedToday ? Colors.amber.shade900 : primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasRequestedToday
                            ? "SOP Limit: Max 1 food claim per 24 hours. Request trigger is currently paused."
                            : "SOP Limit: You can place 1 food request today.",
                        style: TextStyle(
                          fontSize: 12,
                          color: hasRequestedToday ? Colors.amber.shade900 : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Impact Metrics Grid
          const Text("Impact & Priority Metrics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: MetricStatCard(
                  title: "Meals Received",
                  value: "$totalMealsReceived",
                  subtitle: "Ration Packets",
                  icon: Icons.rice_bowl_outlined,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricStatCard(
                  title: "Active Requests",
                  value: "$activeRequests",
                  subtitle: "In-Progress",
                  icon: Icons.hourglass_top_outlined,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: MetricStatCard(
                  title: "Priority Score",
                  value: "$priorityScore / 100",
                  subtitle: missedPickups > 0 ? "-${missedPickups * 15} for missed pickups" : "Top Priority Queue",
                  icon: Icons.speed_outlined,
                  color: priorityScore < 70 ? Colors.orange.shade800 : primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricStatCard(
                  title: "Missed Pickups",
                  value: "$missedPickups / 3",
                  subtitle: "3x triggers flag",
                  icon: Icons.no_sim_outlined,
                  color: missedPickups > 0 ? Colors.red.shade700 : Colors.grey.shade700,
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

          // SOP Guidelines Button
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              leading: Icon(Icons.rule_folder_outlined, color: primaryGreen),
              title: const Text("Beneficiary SOP Guidelines", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("View rules regarding 1 req/day quota & missed pickup policy"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => SopGuidelinesModal.show(context, role: 'beneficiary'),
            ),
          ),
        ],
      ),
    );
  }
}
