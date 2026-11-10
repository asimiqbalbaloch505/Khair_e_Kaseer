import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:khair_e_kaseer/services/fcm_client_service.dart';

class SOPWarningService {
  static final SOPWarningService _instance = SOPWarningService._internal();
  factory SOPWarningService() => _instance;
  SOPWarningService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Core helper: Sends in-app notification & FCM push notification
  Future<bool> sendSOPNotification({
    required String uid,
    required String title,
    required String body,
    required String sopCategory,
    String? targetFcmToken,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      String token = targetFcmToken ?? '';
      if (token.isEmpty) {
        DocumentSnapshot userDoc = await _firestore.collection('Users').doc(uid).get();
        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>? ?? {};
          token = data['fcmToken'] ?? '';
        }
      }

      // 1. Add log to /Users/{uid}/notifications/{id}
      await _firestore.collection('Users').doc(uid).collection('notifications').add({
        'title': title,
        'body': body,
        'sopCategory': sopCategory,
        'type': sopCategory,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        if (extraData != null) ...extraData,
      });

      // 2. Dispatch FCM Push Notification
      if (token.isNotEmpty) {
        await FCMClientService.sendNotificationToUserToken(
          targetFcmToken: token,
          title: title,
          body: body,
          extraData: {
            'sopCategory': sopCategory,
            'type': 'sop_notification',
          },
        );
      }
      return true;
    } catch (e) {
      debugPrint("Error in sendSOPNotification: $e");
      return false;
    }
  }

  // --- BENEFICIARY NOTIFICATION TRIGGERS ---

  Future<bool> notifyBeneficiaryDailyLimit(String uid) {
    return sendSOPNotification(
      uid: uid,
      title: "Daily Limit Reached",
      body: "Daily Limit Reached: You have already requested food today. Beneficiaries are allowed 1 request per day as per SOP 3.1.",
      sopCategory: "SOP 3.1 Daily Limit",
    );
  }

  Future<bool> notifyBeneficiaryMissedPickup(String uid) {
    return sendSOPNotification(
      uid: uid,
      title: "Missed Pickup Alert",
      body: "Missed Pickup Alert: You missed a scheduled pickup. Missing 3 pickups will lower your queue priority (SOP 3.3).",
      sopCategory: "SOP 3.3 Missed Pickups",
    );
  }

  Future<bool> notifyBeneficiaryResellOrMisuse(String uid) {
    return sendSOPNotification(
      uid: uid,
      title: "Account Under Review",
      body: "Account Under Review: Suspicious account activity detected. Reselling or creating multiple accounts is strictly prohibited (SOP 3.4).",
      sopCategory: "SOP 3.4 Misuse Prevention",
    );
  }

  // --- DONOR NOTIFICATION TRIGGERS ---

  Future<bool> notifyDonorGeminiQualityFlag(String uid) {
    return sendSOPNotification(
      uid: uid,
      title: "Food Quality Issue",
      body: "Food Quality Issue: Your upload was flagged for potential quality or hygiene issues by our automated audit (SOP 1.1). Please ensure food has 4–6 hours freshness.",
      sopCategory: "SOP 1.1 Freshness & Hygiene",
    );
  }

  Future<bool> notifyDonorPackagedExpiryFlag(String uid) {
    return sendSOPNotification(
      uid: uid,
      title: "Packaged Food Expiry Alert",
      body: "Packaged Food Expiry Alert: Donated packaged items must have at least 24 hours remaining before expiry (SOP 1.6).",
      sopCategory: "SOP 1.6 Packaged Expiry",
    );
  }

  Future<bool> notifyDonorUnsafeUploadWarning(String uid, int warningCount) {
    return sendSOPNotification(
      uid: uid,
      title: "Warning Issued ($warningCount/2)",
      body: "Warning Issued ($warningCount/2): Your donation post received an SOP flag. Accounts with >2 flags are sent to manual review.",
      sopCategory: "SOP 1.2 Safe Donation",
    );
  }

  // --- VOLUNTEER / RIDER NOTIFICATION TRIGGERS ---

  Future<bool> notifyRiderPickupDelay(String uid) {
    return sendSOPNotification(
      uid: uid,
      title: "Pickup Delay Alert",
      body: "Pickup Delay Alert: Pickup time exceeded 30 minutes. Please complete pickups promptly to ensure food safety (SOP 2.1).",
      sopCategory: "SOP 2.1 Timely Pickup",
    );
  }

  Future<bool> notifyRiderDeliveryDelay(String uid) {
    return sendSOPNotification(
      uid: uid,
      title: "Delivery Delay Alert",
      body: "Delivery Delay Alert: Delivery time exceeded 60 minutes. Timely delivery is critical for food freshness (SOP 2.2).",
      sopCategory: "SOP 2.2 Timely Delivery",
    );
  }

  Future<bool> notifyRiderRejectionDispute(String uid) {
    return sendSOPNotification(
      uid: uid,
      title: "Food Safety Inspection",
      body: "Food Safety Inspection: A food delivery report was submitted regarding food condition. Our team is auditing the POD (SOP 2.6).",
      sopCategory: "SOP 2.6 POD Verification",
    );
  }

  // --- SYSTEM / GENERAL WARNING NOTIFICATIONS ---

  Future<bool> notifyWarningIssued(String uid, int warningCount, String sopCategory, String reason) {
    return sendSOPNotification(
      uid: uid,
      title: "SOP Warning #$warningCount",
      body: "SOP Warning #$warningCount: You have received a warning for violating $sopCategory. Reason: $reason.",
      sopCategory: sopCategory,
    );
  }

  Future<bool> notifyAccountManualReview(String uid) {
    return sendSOPNotification(
      uid: uid,
      title: "Account Flagged",
      body: "Account Flagged: Your account has received >2 warnings and is now under manual review. Please contact support if you believe this is an error.",
      sopCategory: "Account Status Review",
    );
  }

  /// Issues an official warning to a user, updates Firestore /Users/{uid},
  /// increments warningCount, appends warningHistory, sets isFlagged,
  /// automatically moves status to "under_review" if warningCount > 2,
  /// and sends an FCM push notification detailing the SOP violation.
  Future<bool> issueWarning({
    required String uid,
    required String reason,
    required List<String> sopsViolated,
    String issuedBy = "Admin System",
    String? violationId,
  }) async {
    try {
      DocumentReference userRef = _firestore.collection('Users').doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      if (!userDoc.exists) {
        debugPrint("User $uid not found in Firestore.");
        return false;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};
      int currentWarnings = (userData['warningCount'] ?? 0) as int;
      int newWarningCount = currentWarnings + 1;
      String currentStatus = (userData['status'] ?? userData['verificationStatus'] ?? 'active').toString();

      String newStatus = newWarningCount > 2 ? 'under_review' : (currentStatus == 'banned' ? 'banned' : 'active');

      Map<String, dynamic> warningEntry = {
        'warningId': DateTime.now().millisecondsSinceEpoch.toString(),
        'reason': reason,
        'sopsViolated': sopsViolated,
        'issuedBy': issuedBy,
        'timestamp': DateTime.now().toIso8601String(),
        'violationId': violationId ?? '',
      };

      await userRef.update({
        'warningCount': newWarningCount,
        'isFlagged': true,
        'status': newStatus,
        'flaggedReason': reason,
        'lastWarningAt': FieldValue.serverTimestamp(),
        'warningHistory': FieldValue.arrayUnion([warningEntry]),
      });

      if (violationId != null && violationId.isNotEmpty) {
        try {
          await _firestore.collection('sop_violations').doc(violationId).update({
            'actionStatus': 'Warning Issued',
            'actionTakenAt': FieldValue.serverTimestamp(),
            'actionTakenBy': issuedBy,
          });
        } catch (e) {
          debugPrint("Failed to update violation status: $e");
        }
      }

      String sopCat = sopsViolated.isNotEmpty ? sopsViolated.first : "General SOP";
      if (newWarningCount > 2) {
        await notifyAccountManualReview(uid);
      } else {
        await notifyWarningIssued(uid, newWarningCount, sopCat, reason);
      }

      return true;
    } catch (e) {
      debugPrint("Error issuing warning to user $uid: $e");
      return false;
    }
  }

  /// Clears user flags and optionally resets warningCount to 0, returning status to 'active'
  Future<bool> clearFlags({
    required String uid,
    bool resetWarnings = true,
    String clearedBy = "Admin",
  }) async {
    try {
      DocumentReference userRef = _firestore.collection('Users').doc(uid);
      Map<String, dynamic> updateData = {
        'isFlagged': false,
        'status': 'active',
        'flaggedReason': FieldValue.delete(),
        'clearedAt': FieldValue.serverTimestamp(),
        'clearedBy': clearedBy,
      };

      if (resetWarnings) {
        updateData['warningCount'] = 0;
      }

      await userRef.update(updateData);

      await sendSOPNotification(
        uid: uid,
        title: "Account Flags Cleared",
        body: "Your account flags have been cleared by administration. Thank you for following app SOPs.",
        sopCategory: "Account Status Cleared",
      );

      return true;
    } catch (e) {
      debugPrint("Error clearing flags for $uid: $e");
      return false;
    }
  }

  /// Updates account status ('active', 'under_review', 'suspended', 'banned')
  Future<bool> updateAccountStatus({
    required String uid,
    required String newStatus,
    String? reason,
    int? suspendDays,
  }) async {
    try {
      DocumentReference userRef = _firestore.collection('Users').doc(uid);

      Map<String, dynamic> updateData = {
        'status': newStatus,
        'statusReason': reason ?? '',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'suspended' && suspendDays != null) {
        DateTime resumeDate = DateTime.now().add(Duration(days: suspendDays));
        updateData['suspendedUntil'] = Timestamp.fromDate(resumeDate);
      } else if (newStatus == 'active') {
        updateData['suspendedUntil'] = FieldValue.delete();
      }

      await userRef.update(updateData);

      String title = newStatus == 'banned'
          ? "Account Banned"
          : newStatus == 'suspended'
              ? "Account Suspended ($suspendDays Days)"
              : "Account Status Updated ($newStatus)";

      String body = reason != null && reason.isNotEmpty
          ? "Status changed to ${newStatus.toUpperCase()}. Reason: $reason"
          : "Your account status is now ${newStatus.toUpperCase()}.";

      await sendSOPNotification(
        uid: uid,
        title: title,
        body: body,
        sopCategory: "Account Status Update",
      );

      return true;
    } catch (e) {
      debugPrint("Error updating status for $uid: $e");
      return false;
    }
  }

  /// Logs an SOP violation instance into Firestore collection /sop_violations
  Future<String?> logSOPViolation({
    required String uid,
    required String role,
    required String violationType,
    required String proofDetails,
    String? photoUrl,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      DocumentReference docRef = await _firestore.collection('sop_violations').add({
        'uid': uid,
        'userRole': role,
        'violationType': violationType,
        'proofDetails': proofDetails,
        'photoUrl': photoUrl ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'actionStatus': 'Pending Review',
        'extraData': extraData ?? {},
      });

      return docRef.id;
    } catch (e) {
      debugPrint("Error logging SOP violation: $e");
      return null;
    }
  }

  Future<bool> sendSOPWarningNotification({
    required String uid,
    required String targetFcmToken,
    required String title,
    required String message,
    required String sopName,
  }) async {
    return sendSOPNotification(
      uid: uid,
      title: title,
      body: message,
      sopCategory: sopName,
      targetFcmToken: targetFcmToken,
    );
  }
}
