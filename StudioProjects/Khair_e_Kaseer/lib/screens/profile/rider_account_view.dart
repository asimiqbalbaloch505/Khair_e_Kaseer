import 'package:flutter/material.dart';
import 'package:khair_e_kaseer/screens/profile/warning_history_widget.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class RiderAccountView extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userData;
  final VoidCallback onEditProfile;

  const RiderAccountView({
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

    int totalDelivered = (userData['totalDeliveriesCount'] ?? 38) as int;
    int avgDeliveryMins = (userData['avgDeliveryTimeMins'] ?? 28) as int;
    double completionRate = ((userData['completionRate'] ?? 97.5) as num).toDouble();
    double totalKmTracked = ((userData['totalKmTracked'] ?? 112.0) as num).toDouble();
    int fuelIncentivePkr = (totalKmTracked * 15).toInt();

    int pickupDelayFlags = (userData['pickupDelayFlagsCount'] ?? 0) as int;
    int deliveryDelayFlags = (userData['deliveryDelayFlagsCount'] ?? 0) as int;
    double podApprovalRate = ((userData['podApprovalRate'] ?? 99.0) as num).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rider Operational SLA Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: primaryGreen.withOpacity(0.12),
                  child: Icon(Icons.two_wheeler_outlined, color: primaryGreen, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${completionRate.toStringAsFixed(1)}% Task Completion SLA",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "POD Approval: ${podApprovalRate.toStringAsFixed(1)}% | Avg Time: $avgDeliveryMins mins",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Operational & Incentive Metrics
          const Text("Delivery & Incentive Metrics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: MetricStatCard(
                  title: "Total Delivered",
                  value: "$totalDelivered Tasks",
                  subtitle: "Successful Recoveries",
                  icon: Icons.check_circle_outline,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricStatCard(
                  title: "Avg Delivery Time",
                  value: "$avgDeliveryMins Mins",
                  subtitle: "SLA Limit: 60 Mins",
                  icon: Icons.timer_outlined,
                  color: avgDeliveryMins > 45 ? Colors.orange.shade800 : primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: MetricStatCard(
                  title: "Distance Tracked",
                  value: "${totalKmTracked.toStringAsFixed(0)} km",
                  subtitle: "Fuel Incentive: Rs. $fuelIncentivePkr",
                  icon: Icons.route_outlined,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricStatCard(
                  title: "Delay Flags",
                  value: "${pickupDelayFlags + deliveryDelayFlags} Total",
                  subtitle: "Pickup >30m / Delivery >60m",
                  icon: Icons.alarm_off_outlined,
                  color: (pickupDelayFlags + deliveryDelayFlags) > 0 ? Colors.red.shade700 : Colors.grey.shade700,
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

          // Rider SOP Guidelines Button
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              leading: Icon(Icons.rule_folder_outlined, color: primaryGreen),
              title: const Text("Rider Operational & Timeliness SOPs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("30m pickup SLA, 60m delivery SLA, & POD photo standards"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => SopGuidelinesModal.show(context, role: 'volunteer'),
            ),
          ),
        ],
      ),
    );
  }
}
