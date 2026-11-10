import 'package:flutter/material.dart';

class OrderStatusStepper extends StatelessWidget {
  final String orderStatus;
  final String deliveryType; // 'rider_delivery' or 'self_pickup'

  const OrderStatusStepper({
    super.key,
    required this.orderStatus,
    required this.deliveryType,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF347A5C);
    bool isSelfPickup = deliveryType.toLowerCase().contains('pickup') ||
        deliveryType.toLowerCase().contains('self');

    List<Map<String, String>> steps = isSelfPickup
        ? [
            {'title': 'Reserved', 'desc': 'Item Claimed'},
            {'title': 'En Route', 'desc': 'Heading to Donor'},
            {'title': 'Handover', 'desc': 'OTP Verified'},
          ]
        : [
            {'title': 'Claimed', 'desc': 'Order Placed'},
            {'title': 'Assigned', 'desc': 'Rider En Route'},
            {'title': 'Picked Up', 'desc': 'Handed to Rider'},
            {'title': 'Delivered', 'desc': 'Received Food'},
          ];

    int currentStepIndex = _calculateStepIndex(orderStatus, isSelfPickup);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSelfPickup ? "Self-Pickup Progress" : "Rider Delivery Progress",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${currentStepIndex + 1}/${steps.length} Steps",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: List.generate(steps.length, (index) {
              bool isCompleted = index <= currentStepIndex;
              bool isCurrent = index == currentStepIndex;

              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (index > 0)
                          Expanded(
                            child: Container(
                              height: 3,
                              color: index <= currentStepIndex ? primaryGreen : Colors.grey.shade300,
                            ),
                          ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isCompleted ? primaryGreen : Colors.grey.shade200,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCurrent ? primaryGreen : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            isCompleted ? Icons.check : Icons.circle,
                            size: 14,
                            color: isCompleted ? Colors.white : Colors.grey.shade400,
                          ),
                        ),
                        if (index < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 3,
                              color: index < currentStepIndex ? primaryGreen : Colors.grey.shade300,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index]['title']!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isCompleted ? primaryGreen : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      steps[index]['desc']!,
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  int _calculateStepIndex(String status, bool isSelfPickup) {
    String s = status.trim().toLowerCase();

    if (isSelfPickup) {
      if (s == 'completed' || s == 'delivered' || s == 'handed over' || s == 'picked') {
        return 2;
      } else if (s == 'en route' || s == 'arrived' || s == 'ready') {
        return 1;
      }
      return 0; // Reserved
    } else {
      if (s == 'completed' || s == 'delivered') {
        return 3;
      } else if (s == 'picked' || s == 'picked_up' || s == 'handed over') {
        return 2;
      } else if (s == 'accepted' || s == 'rider_assigned' || s == 'assigned') {
        return 1;
      }
      return 0; // Claimed
    }
  }
}
