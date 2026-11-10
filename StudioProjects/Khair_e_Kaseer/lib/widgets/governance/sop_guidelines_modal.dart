import 'package:flutter/material.dart';

class SopGuidelinesModal extends StatelessWidget {
  final String role; // 'donor', 'volunteer' / 'rider', 'beneficiary'
  final String? customTitle;
  final List<Map<String, String>>? customRules;

  const SopGuidelinesModal({
    super.key,
    required this.role,
    this.customTitle,
    this.customRules,
  });

  static void show(BuildContext context, {required String role, String? customTitle, List<Map<String, String>>? customRules}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SopGuidelinesModal(
        role: role,
        customTitle: customTitle,
        customRules: customRules,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF347A5C);
    String normalizedRole = role.toLowerCase().trim();

    String title = customTitle ?? _getRoleTitle(normalizedRole);
    List<Map<String, String>> rules = customRules ?? _getRoleRules(normalizedRole);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          ...rules.map((rule) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rule['desc'] ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Understood & Accept SOPs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleTitle(String role) {
    if (role == 'donor' || role == 'ngo') {
      return "Donor Food Safety & Hygiene SOPs";
    } else if (role == 'volunteer' || role == 'rider') {
      return "Volunteer Rider Operational SOPs";
    } else {
      return "Beneficiary Standard Operating Procedures";
    }
  }

  List<Map<String, String>> _getRoleRules(String role) {
    if (role == 'donor' || role == 'ngo') {
      return [
        {
          'title': '1. Cooked Food Freshness (4-6 Hours)',
          'desc': 'Cooked meals must be posted and picked up within 4 to 6 hours of preparation to prevent food spoilage.'
        },
        {
          'title': '2. Authentic Photo Proof',
          'desc': 'Post clear, real photos of the food item. Fake or stock images are flagged by Gemini AI audits.'
        },
        {
          'title': '3. Hygienic Packaging',
          'desc': 'Ensure food is sealed in clean, food-grade containers or covered pans before rider arrival.'
        },
        {
          'title': '4. Accurate Quantity & Expiry',
          'desc': 'Accurately specify item weight/portions and confirm packaged items are well within expiration date.'
        },
      ];
    } else if (role == 'volunteer' || role == 'rider') {
      return [
        {
          'title': '1. Pickup SLA (<30 Mins)',
          'desc': 'Arrive at donor location within 30 minutes of accepting task.'
        },
        {
          'title': '2. Delivery SLA (<60 Mins)',
          'desc': 'Deliver food items to beneficiary/NGO within 60 minutes of pickup to maintain food temperature.'
        },
        {
          'title': '3. Proof of Delivery (POD)',
          'desc': 'Take a clear handover photo showing food delivered to recipient.'
        },
        {
          'title': '4. Dual-OTP Verification',
          'desc': 'Enter beneficiary OTP code upon handover to complete order status.'
        },
      ];
    } else {
      return [
        {
          'title': '1. Daily Request Limit',
          'desc': 'Beneficiaries can request maximum 1 food packet per 24-hour cycle to ensure fair community distribution.'
        },
        {
          'title': '2. Timely Arrival for Pickup',
          'desc': 'Be present at designated pickup points within 30 minutes of rider arrival or self-pickup window.'
        },
        {
          'title': '3. Missed Pickup Policy',
          'desc': '3 unexcused missed pickups reduce queue priority score and assign a warning flag.'
        },
        {
          'title': '4. Dual-OTP Handover',
          'desc': 'Provide your secure delivery OTP code to the rider upon receiving the food.'
        },
      ];
    }
  }
}
