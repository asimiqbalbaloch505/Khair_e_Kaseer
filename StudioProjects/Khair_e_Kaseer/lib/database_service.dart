import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();


  Future<void> createUser(String uid, Map<String, dynamic> userData) async {
    try {

      await _db.child('Users').child(uid).set({
        "userId": uid,
        "firstName": userData['firstName'],
        "lastName": userData['lastName'],
        "email": userData['email'],
        "phone": userData['phone'],
        "role": userData['role'],
        "isVerified": false,
        "createdAt": ServerValue.timestamp,
      });
      print("Success: Data saved to Realtime Database!");
    } catch (e) {
      print("Database Error: $e");

      throw Exception(e.toString());
    }
  }
}