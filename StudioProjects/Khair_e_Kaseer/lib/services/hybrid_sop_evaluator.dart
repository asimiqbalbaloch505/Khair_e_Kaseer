import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:khair_e_kaseer/services/sop_warning_service.dart';

class HybridSOPEvaluator {
  static final HybridSOPEvaluator _instance = HybridSOPEvaluator._internal();
  factory HybridSOPEvaluator() => _instance;
  HybridSOPEvaluator._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SOPWarningService _warningService = SOPWarningService();

  /// 1. Beneficiary Max 1 Request / Day Limit
  /// Checks if the beneficiary has already submitted a food claim today.
  Future<bool> checkBeneficiaryDailyLimit(String beneficiaryId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      QuerySnapshot snapshot = await _firestore
          .collection('food_claims')
          .where('beneficiaryId', isEqualTo: beneficiaryId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      if (snapshot.docs.isNotEmpty) {
        String proof = "Attempted ${snapshot.docs.length + 1} requests on ${startOfDay.toIso8601String().substring(0, 10)}";

        String? violationId = await _warningService.logSOPViolation(
          uid: beneficiaryId,
          role: 'beneficiary',
          violationType: 'Beneficiary Daily Request Limit Exceeded',
          proofDetails: proof,
        );

        // Notify user specifically about SOP 3.1
        await _warningService.notifyBeneficiaryDailyLimit(beneficiaryId);

        // Auto-assign warning for violating daily limit SOP
        await _warningService.issueWarning(
          uid: beneficiaryId,
          reason: "Attempted to submit more than 1 food request in 24 hours.",
          sopsViolated: ["Beneficiary Daily Limit SOP 3.1"],
          violationId: violationId,
        );

        return false; // Limit exceeded
      }
      return true; // Limit okay
    } catch (e) {
      debugPrint("Error checking beneficiary daily limit: $e");
      return true;
    }
  }

  /// 2. Rider Pickup (>30m) & Delivery (>60m) Timeout Flags
  /// Evaluates rider timestamps against platform delivery SLA guidelines.
  Future<Map<String, bool>> checkRiderTimeouts({
    required String riderId,
    required String taskId,
    required DateTime acceptedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
  }) async {
    bool pickupTimeout = false;
    bool deliveryTimeout = false;

    if (pickedUpAt != null) {
      int pickupDurationMinutes = pickedUpAt.difference(acceptedAt).inMinutes;
      if (pickupDurationMinutes > 30) {
        pickupTimeout = true;
        String proof = "Pickup took $pickupDurationMinutes mins (Max 30 mins limit). Task ID: $taskId";

        String? vId = await _warningService.logSOPViolation(
          uid: riderId,
          role: 'volunteer',
          violationType: 'Pickup Timeout (>30m)',
          proofDetails: proof,
        );

        await _warningService.notifyRiderPickupDelay(riderId);

        await _warningService.issueWarning(
          uid: riderId,
          reason: "Pickup elapsed time ($pickupDurationMinutes mins) exceeded 30-minute threshold (SOP 2.1).",
          sopsViolated: ["Rider Timely Pickup SOP 2.1"],
          violationId: vId,
        );
      }
    }

    if (deliveredAt != null) {
      DateTime startTime = pickedUpAt ?? acceptedAt;
      int deliveryDurationMinutes = deliveredAt.difference(startTime).inMinutes;
      if (deliveryDurationMinutes > 60) {
        deliveryTimeout = true;
        String proof = "Delivery took $deliveryDurationMinutes mins (Max 60 mins limit). Task ID: $taskId";

        String? vId = await _warningService.logSOPViolation(
          uid: riderId,
          role: 'volunteer',
          violationType: 'Delivery Timeout (>60m)',
          proofDetails: proof,
        );

        await _warningService.notifyRiderDeliveryDelay(riderId);

        await _warningService.issueWarning(
          uid: riderId,
          reason: "Delivery elapsed time ($deliveryDurationMinutes mins) exceeded 60-minute threshold (SOP 2.2).",
          sopsViolated: ["Rider Timely Delivery SOP 2.2"],
          violationId: vId,
        );
      }
    }

    return {
      'pickupTimeout': pickupTimeout,
      'deliveryTimeout': deliveryTimeout,
    };
  }

  /// 3. Beneficiary 3 Missed Pickups Flag
  /// Checks total missed/no-show pickups for a beneficiary.
  Future<bool> checkBeneficiaryMissedPickups(String beneficiaryId) async {
    try {
      QuerySnapshot missedSnapshot = await _firestore
          .collection('food_claims')
          .where('beneficiaryId', isEqualTo: beneficiaryId)
          .where('status', whereIn: ['missed_pickup', 'no_show', 'cancelled_by_beneficiary'])
          .get();

      int count = missedSnapshot.docs.length;
      if (count >= 3) {
        String proof = "Total missed pickups recorded: $count instance(s).";

        String? vId = await _warningService.logSOPViolation(
          uid: beneficiaryId,
          role: 'beneficiary',
          violationType: 'Beneficiary 3x Missed Pickups',
          proofDetails: proof,
        );

        await _warningService.notifyBeneficiaryMissedPickup(beneficiaryId);

        await _warningService.issueWarning(
          uid: beneficiaryId,
          reason: "Accumulated $count missed/abandoned pickup instances (SOP 3.3).",
          sopsViolated: ["Beneficiary Pickup Reliability SOP 3.3"],
          violationId: vId,
        );

        return false; // Violating
      }
      return true; // Okay
    } catch (e) {
      debugPrint("Error checking missed pickups: $e");
      return true;
    }
  }

  /// 4. Dual-OTP Verification Checks
  /// Validates handover OTP codes at donor pickup and beneficiary delivery points.
  Future<bool> verifyDualOTP({
    required String inputOtp,
    required String expectedOtp,
    required String role,
    required String userId,
    required String taskId,
  }) async {
    if (inputOtp.trim() == expectedOtp.trim()) {
      return true;
    }

    String proof = "Invalid OTP provided: '$inputOtp' vs expected for Task ID: $taskId";
    await _warningService.logSOPViolation(
      uid: userId,
      role: role,
      violationType: 'Dual OTP Verification Failure',
      proofDetails: proof,
    );

    return false;
  }
}
