import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collections
  static const String usersCollection = 'profiles';
  static const String hostelsCollection = 'hostels';
  static const String roomsCollection = 'rooms';
  static const String applicationsCollection = 'applications';
  
  // Auth methods
  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // User management
  static Future<void> createUserDocument(Map<String, dynamic> userData) async {
    final user = currentUser;
    if (user == null) throw Exception('No authenticated user');
    
    await _firestore
        .collection(usersCollection)
        .doc(user.uid)
        .set(userData);
  }
  
  static Future<DocumentSnapshot> getUserDocument(String userId) async {
    return await _firestore
        .collection(usersCollection)
        .doc(userId)
        .get();
  }
  
  static Future<void> updateUserDocument(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) throw Exception('No authenticated user');
    
    await _firestore
        .collection(usersCollection)
        .doc(user.uid)
        .update(data);
  }
  
  // Hostel management
  static Future<void> addHostel(Map<String, dynamic> hostelData) async {
    await _firestore
        .collection(hostelsCollection)
        .add(hostelData);
  }
  
  static Future<QuerySnapshot> getHostels() async {
    return await _firestore
        .collection(hostelsCollection)
        .get();
  }
  
  static Future<void> updateHostel(String hostelId, Map<String, dynamic> data) async {
    await _firestore
        .collection(hostelsCollection)
        .doc(hostelId)
        .update(data);
  }
  
  // Room management
  static Future<void> addRoom(String hostelId, Map<String, dynamic> roomData) async {
    await _firestore
        .collection(hostelsCollection)
        .doc(hostelId)
        .collection('rooms')
        .add(roomData);
  }
  
  static Future<QuerySnapshot> getRooms(String hostelId) async {
    return await _firestore
        .collection(hostelsCollection)
        .doc(hostelId)
        .collection('rooms')
        .get();
  }
  
  // Application management
  static Future<void> submitApplication(Map<String, dynamic> applicationData) async {
    final user = currentUser;
    if (user == null) throw Exception('No authenticated user');
    
    await _firestore
        .collection(applicationsCollection)
        .add({
      ...applicationData,
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
  
  static Future<QuerySnapshot> getUserApplications() async {
    final user = currentUser;
    if (user == null) throw Exception('No authenticated user');
    
    return await _firestore
        .collection(applicationsCollection)
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();
  }
  
  static Future<QuerySnapshot> getAllApplications() async {
    return await _firestore
        .collection(applicationsCollection)
        .orderBy('createdAt', descending: true)
        .get();
  }
  // Real-time listeners
  static Stream<QuerySnapshot> getApplicationsStream() {
    return _firestore
        .collection(applicationsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
  
  static Stream<QuerySnapshot> getUserApplicationsStream() {
    final user = currentUser;
    if (user == null) throw Exception('No authenticated user');
    
    return _firestore
        .collection(applicationsCollection)
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
