import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:khair_e_kaseer/screens/donor/donor_main_navigation_screen.dart';
import 'package:khair_e_kaseer/services/fcm_client_service.dart';

class PostFoodItemScreen extends StatefulWidget {
  const PostFoodItemScreen({super.key});

  @override
  State<PostFoodItemScreen> createState() => _PostFoodItemScreenState();
}

class _PostFoodItemScreenState extends State<PostFoodItemScreen> {
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _bulkQuantityController = TextEditingController();
  final TextEditingController _pickupAddressController = TextEditingController();

  int _portions = 10;
  bool _isBulk = false;

  String _selectedDisplayTime = "30 mins";

  File? _imageFile;
  bool _isLoading = false;
  bool _isFetchingProfile = true;

  String _donorName = "";
  String _donorPhone = "";
  String? _donorFcmToken;

  final List<String> _times = [
    "5 mins",
    "30 mins",
    "1 hour",
    "3 hours",
    "6 hours",
    "12 hours"
  ];

  @override
  void initState() {
    super.initState();
    _fetchDonorProfile();
  }

  /// Automatically retrieves saved profile address and contact details
  Future<void> _fetchDonorProfile() async {
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
        _donorName = data['name'] ?? data['fullName'] ?? 'Donor';
        _donorPhone = data['phone'] ?? data['phoneNumber'] ?? '';
        _donorFcmToken = data['fcmToken'];

        String savedAddress =
            data['address'] ?? data['pickupAddress'] ?? data['location'] ?? '';
        _pickupAddressController.text = savedAddress;
      }
    } catch (e) {
      debugPrint("Error fetching donor profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isFetchingProfile = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 40,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String> _convertImageToBase64(File image) async {
    List<int> imageBytes = await image.readAsBytes();
    return base64Encode(imageBytes);
  }

  DateTime _calculateExpiryDate(String displayTime) {
    DateTime now = DateTime.now();
    if (displayTime == "5 mins") return now.add(const Duration(minutes: 5));
    if (displayTime == "30 mins") return now.add(const Duration(minutes: 30));
    if (displayTime == "1 hour") return now.add(const Duration(hours: 1));
    if (displayTime == "3 hours") return now.add(const Duration(hours: 3));
    if (displayTime == "6 hours") return now.add(const Duration(hours: 6));
    if (displayTime == "12 hours") return now.add(const Duration(hours: 12));
    return now.add(const Duration(hours: 1));
  }

  Future<void> _postFoodItem() async {
    final user = FirebaseAuth.instance.currentUser;

    if (_foodNameController.text.trim().isEmpty) {
      _showSnackBar("Please add food name", Colors.red);
      return;
    }
    if (_isBulk && _bulkQuantityController.text.trim().isEmpty) {
      _showSnackBar(
          "Please specify bulk quantity (e.g. 50 kg, 3 large pots)", Colors.red);
      return;
    }
    if (_pickupAddressController.text.trim().isEmpty) {
      _showSnackBar("Please provide or confirm pickup address", Colors.red);
      return;
    }
    if (_imageFile == null) {
      _showSnackBar("Please select a food image", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String base64Image = await _convertImageToBase64(_imageFile!);
      DateTime expiryDateTime = _calculateExpiryDate(_selectedDisplayTime);
      String confirmedPickupAddress = _pickupAddressController.text.trim();

      // Optionally update user's default address in profile if changed
      if (user != null) {
        FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .set({'address': confirmedPickupAddress}, SetOptions(merge: true));
      }

      final donationData = {
        'foodTitle': _foodNameController.text.trim(),
        'foodName': _foodNameController.text.trim(),
        'donationType': _isBulk ? 'bulk' : 'family_portion',
        'isBulk': _isBulk,
        'quantity': _isBulk ? 0 : _portions,
        'remainingPortions': _isBulk ? 0 : _portions,
        'quantityDescription': _isBulk
            ? _bulkQuantityController.text.trim()
            : "$_portions Portions",
        'expiryDisplay': _selectedDisplayTime,
        'expiryDateTime': Timestamp.fromDate(expiryDateTime),
        'description': _descriptionController.text.trim(),
        'foodImage': base64Image,
        'status': 'Available',
        'donorId': user?.uid ?? "",
        'donorName': _donorName,
        'donorPhone': _donorPhone,
        'pickupAddress': confirmedPickupAddress,
        'address': confirmedPickupAddress,
        'donorFcmToken': _donorFcmToken,
        'timestamp': FieldValue.serverTimestamp(),
      };

      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference ref1 =
      FirebaseFirestore.instance.collection('FoodDonations').doc();
      DocumentReference ref2 =
      FirebaseFirestore.instance.collection('Donations').doc(ref1.id);

      batch.set(ref1, donationData);
      batch.set(ref2, donationData);

      await batch.commit();

      if (_isBulk) {
        FCMClientService.sendNotificationToTopic(
          topic: "topic_ngo",
          title: "New Bulk Food Donation Available!",
          body:
          "${_foodNameController.text.trim()} (${_bulkQuantityController.text.trim()}) is available for pickup at $confirmedPickupAddress.",
        );
      } else {
        FCMClientService.sendNotificationToTopic(
          topic: "topic_beneficiary",
          title: "Fresh Food Posted!",
          body:
          "${_foodNameController.text.trim()} ($_portions Portions) has just been posted nearby.",
        );
      }

      if (mounted) {
        _showSnackBar(
            _isBulk
                ? "Bulk Food Posted for NGOs Successfully!"
                : "Food Posted Successfully!",
            Colors.green);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) => const DonorMainNavigationScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar("Error: Data could not be saved", Colors.red);
      debugPrint("Detailed Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: color, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF347A5C);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Khair e Kaseer",
            style: TextStyle(color: Colors.white)),
      ),
      body: _isFetchingProfile
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add Food",
                style:
                TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            Container(
              decoration: BoxDecoration(
                color: _isBulk
                    ? primaryGreen.withOpacity(0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _isBulk ? primaryGreen : Colors.grey.shade300,
                    width: 1.5),
              ),
              child: SwitchListTile(
                value: _isBulk,
                activeColor: primaryGreen,
                title: const Text(
                  "Is this a Bulk Food Donation?",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  _isBulk
                      ? "Large quantities (e.g. Wedding catering, 50+ kg)"
                      : "Standard family or individual portions",
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700),
                ),
                onChanged: (val) {
                  setState(() => _isBulk = val);
                },
              ),
            ),

            if (_isBulk) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade900),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Bulk items are listed directly to verified NGOs equipped with heavy transport vans for swift distribution.",
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                  border:
                  Border.all(color: Colors.blue.shade100, width: 2),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.file(_imageFile!, fit: BoxFit.cover),
                )
                    : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo,
                        size: 45, color: Colors.grey),
                    SizedBox(height: 8),
                    Text("Tap to add Food Photo",
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text("Food Name",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _foodNameController,
              decoration: InputDecoration(
                hintText: "e.g. Chicken Biryani / Wedding Surplus",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 20),

            // ===================================================
            // PICKUP LOCATION & CONTACT (CONFIRM / EDIT SAVED)
            // ===================================================
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: primaryGreen.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: primaryGreen),
                        const SizedBox(width: 8),
                        const Text(
                          "Verify Pickup Location",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
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
                      controller: _pickupAddressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Enter exact pickup address/location",
                        labelText: "Pickup Address",
                        prefixIcon: const Icon(Icons.map_outlined),
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

            const SizedBox(height: 20),

            if (_isBulk) ...[
              const Text("Bulk Quantity & Description",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _bulkQuantityController,
                decoration: InputDecoration(
                  hintText:
                  "e.g. 50 kg Rice, 3 Large Catering Containers",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.scale_outlined,
                      color: primaryGreen),
                ),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Expiry Time",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _selectedDisplayTime,
                    isExpanded: true,
                    items: _times.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDisplayTime = val!;
                      });
                    },
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Portions",
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  setState(() => _portions++),
                              icon: const Icon(Icons.add_circle,
                                  color: primaryGreen),
                            ),
                            Text("$_portions",
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                              onPressed: () => setState(() =>
                              _portions > 1 ? _portions-- : null),
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Expiry Time",
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          value: _selectedDisplayTime,
                          isExpanded: true,
                          items: _times.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedDisplayTime = val!;
                            });
                          },
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            const Text("Additional Notes / Instructions",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                "Gate code, parking instructions, or landmark details...",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 35),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _postFoodItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  _isBulk
                      ? "Post Bulk Food for NGOs"
                      : "Post For Pickup",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}