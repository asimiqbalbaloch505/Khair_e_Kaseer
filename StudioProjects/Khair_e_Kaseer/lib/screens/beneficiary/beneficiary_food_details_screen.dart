import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:khair_e_kaseer/screens/beneficiary/beneficiary_rider_tracking_screen.dart';
import 'package:khair_e_kaseer/screens/beneficiary/beneficiary_self_pickup_tracking.dart';
import 'package:khair_e_kaseer/services/fcm_client_service.dart';

class BeneficiaryFoodDetailsScreen extends StatefulWidget {
  const BeneficiaryFoodDetailsScreen({
    super.key,
    required this.foodId,
    required this.foodData,
  });

  final String foodId;
  final Map<String, dynamic> foodData;

  @override
  State<BeneficiaryFoodDetailsScreen> createState() =>
      _BeneficiaryFoodDetailsScreenState();
}

class _BeneficiaryFoodDetailsScreenState
    extends State<BeneficiaryFoodDetailsScreen> {
  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);
  int _selectedPortions = 1;
  String _fulfillmentType = 'Delivery';

  final TextEditingController _deliveryAddressController =
  TextEditingController();
  bool _isFetchingProfile = true;

  String _beneficiaryName = "";
  String _beneficiaryPhone = "";

  @override
  void initState() {
    super.initState();
    _fetchBeneficiaryProfile();
  }

  /// Automatically retrieves saved beneficiary profile address and contact details
  Future<void> _fetchBeneficiaryProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isFetchingProfile = false);
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        _beneficiaryName = data['name'] ?? data['fullName'] ?? 'Beneficiary';
        _beneficiaryPhone = data['phone'] ?? data['phoneNumber'] ?? '';

        String savedAddress =
            data['address'] ?? data['deliveryAddress'] ?? data['location'] ?? '';
        _deliveryAddressController.text = savedAddress;
      }
    } catch (e) {
      debugPrint("Error fetching beneficiary profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isFetchingProfile = false);
      }
    }
  }

  /// Helper method to write notification entries into Firestore
  Future<void> _saveNotificationToFirestore({
    required String title,
    required String body,
    required String targetRole,
    String? recipientId,
    String? orderId,
    String? foodId,
    String? topic,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('Notifications').add({
        'title': title,
        'body': body,
        'targetRole': targetRole,
        'recipientId': recipientId,
        'topic': topic ?? 'topic_volunteer',
        'orderId': orderId,
        'foodId': foodId,
        'createdAt': Timestamp.now(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      debugPrint("Error saving notification to Firestore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isBulk = widget.foodData['isBulk'] == true ||
        widget.foodData['donationType'] == 'bulk';
    int availablePortions = widget.foodData['remainingPortions'] ?? 1;
    int portionLimit = availablePortions > 5 ? 5 : availablePortions;

    String foodTitle = widget.foodData['foodTitle'] ??
        widget.foodData['foodName'] ??
        "Food Item";
    String quantitySubtitle = isBulk
        ? (widget.foodData['quantityDescription'] ?? "Bulk Quantity")
        : "Remaining: $availablePortions Portions";

    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:
        const Text("Request Details", style: TextStyle(color: Colors.black)),
        leading: const BackButton(color: Colors.black),
      ),
      body: _isFetchingProfile
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: (widget.foodData['foodImage'] != null &&
                            widget.foodData['foodImage']
                                .toString()
                                .isNotEmpty)
                            ? Image.memory(
                          base64Decode(widget.foodData['foodImage']),
                          fit: BoxFit.cover,
                        )
                            : Icon(Icons.fastfood,
                            size: 30, color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(foodTitle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text(quantitySubtitle,
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isBulk) ...[
                    const Text(
                      "Portions Required:",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(
                        portionLimit,
                            (index) => GestureDetector(
                          onTap: () => setState(
                                  () => _selectedPortions = index + 1),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedPortions == index + 1
                                  ? primaryGreen
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: primaryGreen.withOpacity(0.3)),
                            ),
                            child: Text(
                              "${index + 1}",
                              style: TextStyle(
                                color: _selectedPortions == index + 1
                                    ? Colors.white
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],

                  // ===================================================
                  // DELIVERY ADDRESS VERIFICATION CARD
                  // ===================================================
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side:
                      BorderSide(color: primaryGreen.withOpacity(0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: primaryGreen),
                              const SizedBox(width: 8),
                              const Text(
                                "Delivery Address",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                              const Spacer(),
                              Text(
                                "Default Loaded",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _deliveryAddressController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText:
                              "Enter your exact delivery address or location",
                              labelText: "Delivery Location",
                              prefixIcon: const Icon(Icons.home_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Text(
                    "How will you get it?",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildFulfillmentOption(
                      context, 'Delivery', Icons.directions_bike),
                  const SizedBox(height: 10),
                  _buildFulfillmentOption(
                      context, 'Pickup', Icons.front_hand_outlined),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;

                        String confirmedDeliveryAddress =
                        _deliveryAddressController.text.trim();

                        if (confirmedDeliveryAddress.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Please enter or verify your delivery address."),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                              child: CircularProgressIndicator()),
                        );

                        try {
                          DocumentSnapshot userDoc = await FirebaseFirestore
                              .instance
                              .collection('Users')
                              .doc(user.uid)
                              .get();

                          String userRole = 'Beneficiary';
                          String? beneficiaryFcmToken;

                          if (userDoc.exists && userDoc.data() != null) {
                            Map<String, dynamic> uData =
                            userDoc.data() as Map<String, dynamic>;
                            userRole = (uData['role'] ?? 'Beneficiary')
                                .toString();
                            beneficiaryFcmToken = uData['fcmToken'];
                            _beneficiaryName = uData['name'] ??
                                uData['fullName'] ??
                                'Beneficiary';
                            _beneficiaryPhone =
                                uData['phone'] ?? uData['phoneNumber'] ?? '';
                          }

                          String orderDisplayCode =
                              "KF-${Random().nextInt(9000) + 1000}";

                          // GENERATE 2 SEPARATE OTPS
                          String generatedPickupOtp =
                          (1000 + Random().nextInt(9000)).toString();
                          String generatedDeliveryOtp =
                          (1000 + Random().nextInt(9000)).toString();

                          DocumentReference newOrderRef =
                          FirebaseFirestore.instance
                              .collection('Orders')
                              .doc();
                          String newOrderId = newOrderRef.id;

                          String resolvedDonorId =
                              widget.foodData['donorId'] ??
                                  widget.foodData['userId'] ??
                                  widget.foodData['donorUid'] ??
                                  '';

                          String donorName =
                              widget.foodData['donorName'] ?? 'Donor';
                          String donorPhone =
                              widget.foodData['donorPhone'] ?? '';
                          String pickupAddress =
                              widget.foodData['pickupAddress'] ??
                                  widget.foodData['address'] ??
                                  'Donor Address';

                          // Fetch Donor FCM Token directly from Users collection if missing
                          String? donorFcmToken =
                          widget.foodData['donorFcmToken'];
                          if ((donorFcmToken == null ||
                              donorFcmToken.isEmpty) &&
                              resolvedDonorId.isNotEmpty) {
                            try {
                              DocumentSnapshot donorDoc =
                              await FirebaseFirestore.instance
                                  .collection('Users')
                                  .doc(resolvedDonorId)
                                  .get();
                              if (donorDoc.exists &&
                                  donorDoc.data() != null) {
                                Map<String, dynamic> dData = donorDoc
                                    .data() as Map<String, dynamic>;
                                donorFcmToken = dData['fcmToken'];
                                if (donorName == 'Donor') {
                                  donorName = dData['name'] ??
                                      dData['fullName'] ??
                                      'Donor';
                                }
                                if (donorPhone.isEmpty) {
                                  donorPhone = dData['phone'] ??
                                      dData['phoneNumber'] ??
                                      '';
                                }
                                if (pickupAddress == 'Donor Address') {
                                  pickupAddress = dData['address'] ??
                                      dData['pickupAddress'] ??
                                      'Donor Address';
                                }
                              }
                            } catch (e) {
                              debugPrint("Error fetching donor token: $e");
                            }
                          }

                          DocumentReference donationRef =
                          FirebaseFirestore.instance
                              .collection('Donations')
                              .doc(widget.foodId);

                          String normalizedFulfillment =
                          _fulfillmentType == 'Pickup'
                              ? 'Self Pickup'
                              : 'Delivery';

                          if (isBulk) {
                            Map<String, dynamic> bulkClaimData = {
                              'status': 'Claimed',
                              'claimedBy': user.uid,
                              'beneficiaryId': user.uid,
                              'beneficiaryName': _beneficiaryName,
                              'beneficiaryPhone': _beneficiaryPhone,
                              'deliveryAddress': confirmedDeliveryAddress,
                              'claimedByRole': userRole,
                              'pickupOtp': generatedPickupOtp,
                              'deliveryOtp': generatedDeliveryOtp,
                              'otp': generatedDeliveryOtp, // backward compatibility
                              'fulfillmentMethod': normalizedFulfillment,
                              'deliveryType': normalizedFulfillment,
                              'orderDocId': newOrderId,
                              'orderId': orderDisplayCode,
                              'claimedAt':
                              DateTime.now().millisecondsSinceEpoch,
                            };

                            await donationRef.set(
                                bulkClaimData, SetOptions(merge: true));

                            await newOrderRef.set({
                              'orderDocId': newOrderId,
                              'orderId': orderDisplayCode,
                              'donationId': widget.foodId,
                              'foodName': foodTitle,
                              'foodTitle': foodTitle,
                              'pickupOtp': generatedPickupOtp,
                              'deliveryOtp': generatedDeliveryOtp,
                              'otp': generatedDeliveryOtp,
                              'beneficiaryId': user.uid,
                              'beneficiaryName': _beneficiaryName,
                              'beneficiaryPhone': _beneficiaryPhone,
                              'deliveryAddress': confirmedDeliveryAddress,
                              'claimedBy': user.uid,
                              'claimedByRole': userRole,
                              'donorId': resolvedDonorId,
                              'donorName': donorName,
                              'donorPhone': donorPhone,
                              'pickupAddress': pickupAddress,
                              'donorFcmToken': donorFcmToken,
                              'beneficiaryFcmToken': beneficiaryFcmToken,
                              'deliveryType': normalizedFulfillment,
                              'fulfillmentMethod': normalizedFulfillment,
                              'status': 'Pending',
                              'timestamp': FieldValue.serverTimestamp(),
                              'portionsClaimed':
                              widget.foodData['quantityDescription'] ??
                                  'Bulk Quantity',
                              'foodImage': widget.foodData['foodImage'],
                              'volunteerId': null,
                            });
                          } else {
                            await FirebaseFirestore.instance
                                .runTransaction((transaction) async {
                              DocumentSnapshot postSnap =
                              await transaction.get(donationRef);

                              int currentRemaining = postSnap.exists
                                  ? (postSnap['remainingPortions'] ?? 1)
                                  : 1;

                              if (currentRemaining >= _selectedPortions) {
                                int newRemaining =
                                    currentRemaining - _selectedPortions;
                                if (postSnap.exists) {
                                  transaction.update(postSnap.reference, {
                                    'remainingPortions': newRemaining,
                                    'status': newRemaining == 0
                                        ? 'Claimed'
                                        : 'Available',
                                    'claimedBy': user.uid,
                                    'beneficiaryId': user.uid,
                                    'beneficiaryName': _beneficiaryName,
                                    'beneficiaryPhone': _beneficiaryPhone,
                                    'deliveryAddress': confirmedDeliveryAddress,
                                    'claimedByRole': userRole,
                                    'pickupOtp': generatedPickupOtp,
                                    'deliveryOtp': generatedDeliveryOtp,
                                    'otp': generatedDeliveryOtp,
                                    'fulfillmentMethod':
                                    normalizedFulfillment,
                                    'deliveryType': normalizedFulfillment,
                                    'orderDocId': newOrderId,
                                    'orderId': orderDisplayCode,
                                  });
                                }

                                transaction.set(newOrderRef, {
                                  'orderDocId': newOrderId,
                                  'donationId': widget.foodId,
                                  'orderId': orderDisplayCode,
                                  'pickupOtp': generatedPickupOtp,
                                  'deliveryOtp': generatedDeliveryOtp,
                                  'otp': generatedDeliveryOtp,
                                  'foodName': foodTitle,
                                  'foodTitle': foodTitle,
                                  'portionsClaimed': _selectedPortions,
                                  'beneficiaryId': user.uid,
                                  'beneficiaryName': _beneficiaryName,
                                  'beneficiaryPhone': _beneficiaryPhone,
                                  'deliveryAddress': confirmedDeliveryAddress,
                                  'claimedBy': user.uid,
                                  'claimedByRole': userRole,
                                  'donorId': resolvedDonorId,
                                  'donorName': donorName,
                                  'donorPhone': donorPhone,
                                  'pickupAddress': pickupAddress,
                                  'donorFcmToken': donorFcmToken,
                                  'beneficiaryFcmToken': beneficiaryFcmToken,
                                  'deliveryType': normalizedFulfillment,
                                  'fulfillmentMethod':
                                  normalizedFulfillment,
                                  'status': 'Pending',
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'foodImage': widget.foodData['foodImage'],
                                  'volunteerId': null,
                                });
                              } else {
                                throw "Not enough portions available!";
                              }
                            });
                          }

                          // Update default saved delivery address in User profile
                          FirebaseFirestore.instance
                              .collection('Users')
                              .doc(user.uid)
                              .set({'address': confirmedDeliveryAddress},
                              SetOptions(merge: true));

                          // ===================================================
                          // NOTIFICATIONS & ALERTS DISPATCH
                          // ===================================================
                          String donorNotificationTitle =
                          normalizedFulfillment == 'Delivery'
                              ? "Food Claimed - Waiting for Rider"
                              : "Self Pickup Selected";
                          String donorNotificationBody =
                          normalizedFulfillment == 'Delivery'
                              ? "A beneficiary has claimed '$foodTitle'. It is now waiting for a rider to accept."
                              : "A beneficiary has claimed '$foodTitle' and selected Self Pickup.";

                          if (donorFcmToken != null &&
                              donorFcmToken.isNotEmpty) {
                            await FCMClientService.sendNotificationToUserToken(
                              targetFcmToken: donorFcmToken,
                              title: donorNotificationTitle,
                              body: donorNotificationBody,
                            );
                          } else {
                            await FCMClientService.sendNotificationToTopic(
                              topic: "topic_donor",
                              title: donorNotificationTitle,
                              body: donorNotificationBody,
                            );
                          }

                          if (resolvedDonorId.isNotEmpty) {
                            await _saveNotificationToFirestore(
                              title: donorNotificationTitle,
                              body: donorNotificationBody,
                              targetRole: "Donor",
                              recipientId: resolvedDonorId,
                              orderId: newOrderId,
                              foodId: widget.foodId,
                            );
                          }

                          if (normalizedFulfillment == 'Delivery') {
                            if (isBulk) {
                              const title = "New Bulk Delivery Available!";
                              final body =
                                  "A bulk food order ($foodTitle) requires a cargo/van rider.";

                              FCMClientService.sendNotificationToTopic(
                                topic: "topic_volunteer_large",
                                title: title,
                                body: body,
                              );

                              await _saveNotificationToFirestore(
                                title: title,
                                body: body,
                                targetRole: "Volunteer",
                                topic: "topic_volunteer_large",
                                orderId: newOrderId,
                                foodId: widget.foodId,
                              );
                            } else {
                              const title = "New Food Delivery Available!";
                              final body =
                                  "A delivery order ($foodTitle - $_selectedPortions portions) is ready for pickup.";

                              FCMClientService.sendNotificationToTopic(
                                topic: "topic_volunteer_small",
                                title: title,
                                body: body,
                              );

                              await _saveNotificationToFirestore(
                                title: title,
                                body: body,
                                targetRole: "Volunteer",
                                topic: "topic_volunteer_small",
                                orderId: newOrderId,
                                foodId: widget.foodId,
                              );
                            }

                            const genTitle = "New Delivery Request!";
                            final genBody =
                                "New delivery request for $foodTitle needs a rider.";

                            FCMClientService.sendNotificationToTopic(
                              topic: "topic_volunteer",
                              title: genTitle,
                              body: genBody,
                            );

                            await _saveNotificationToFirestore(
                              title: genTitle,
                              body: genBody,
                              targetRole: "Volunteer",
                              topic: "topic_volunteer",
                              orderId: newOrderId,
                              foodId: widget.foodId,
                            );
                          } else {
                            const title = "New Pickup Request!";
                            final body =
                                "A beneficiary scheduled a self-pickup for $foodTitle.";

                            FCMClientService.sendNotificationToTopic(
                              topic: "topic_volunteer",
                              title: title,
                              body: body,
                            );

                            await _saveNotificationToFirestore(
                              title: title,
                              body: body,
                              targetRole: "Volunteer",
                              topic: "topic_volunteer",
                              orderId: newOrderId,
                              foodId: widget.foodId,
                            );
                          }

                          if (mounted) Navigator.pop(context);

                          if (normalizedFulfillment == 'Delivery') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    BeneficiaryRiderTrackingScreen(
                                        orderDocId: newOrderId),
                              ),
                            );
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    BeneficiarySelfPickupTrackingScreen(
                                        orderDocId: newOrderId),
                              ),
                            );
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                              Text("Request Placed Successfully!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (mounted) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "REQUEST FOOD",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFulfillmentOption(
      BuildContext context, String type, IconData icon) {
    return GestureDetector(
      onTap: () => setState(() => _fulfillmentType = type),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _fulfillmentType == type
                  ? primaryGreen
                  : Colors.transparent,
              width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryGreen),
            const SizedBox(width: 15),
            Text(type, style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(
              _fulfillmentType == type
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: primaryGreen,
            )
          ],
        ),
      ),
    );
  }
}