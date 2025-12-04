class Doctor {
  final String uid;
  final String category; // Primary specialization
  final String city;
  final String email;
  final String firstName;
  final String location;
  final String lastName;
  final String profileImageUrl;
  final String qualification;
  final String phoneNumber;
  final int yearsOfExperience;
  final double latitude;
  final double longitude;
  final int numberOfReviews;
  final int totalReviews;
  final bool isVerified;
  final String workingAt; // Hospital name
  final String status; // pending / approved / rejected
  final List<String> specialization; // ✅ Multiple specializations

  Doctor({
    required this.uid,
    required this.category,
    required this.city,
    required this.email,
    required this.location,
    required this.firstName,
    required this.lastName,
    required this.profileImageUrl,
    required this.qualification,
    required this.phoneNumber,
    required this.yearsOfExperience,
    required this.latitude,
    required this.longitude,
    required this.numberOfReviews,
    required this.totalReviews,
    required this.isVerified,
    required this.workingAt,
    required this.status,
    required this.specialization,
  });

  factory Doctor.fromMap(
    Map<dynamic, dynamic> data,
    String uid, {
    required id,
  }) {
    return Doctor(
      uid: uid,
      category: data['category'] ?? '',
      city: data['city'] ?? '',
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      qualification: data['qualification'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      yearsOfExperience: data['yearsOfExperience'] ?? 0,
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      numberOfReviews: data['numberOfReviews'] ?? 0,
      totalReviews: data['totalReviews'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      workingAt: data['workingAt'] ?? 'Unknown Hospital',
      status: data['status'] ?? 'pending',
      specialization: data['specializations'] != null
          ? List<String>.from(data['specialization'])
          : <String>[],
      location: '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'category': category,
      'city': city,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'profileImageUrl': profileImageUrl,
      'qualification': qualification,
      'phoneNumber': phoneNumber,
      'yearsOfExperience': yearsOfExperience,
      'latitude': latitude,
      'longitude': longitude,
      'numberOfReviews': numberOfReviews,
      'totalReviews': totalReviews,
      'isVerified': isVerified,
      'workingAt': workingAt,
      'status': status,
      'specializations': specialization,
    };
  }

  double get averageRating {
    if (numberOfReviews == 0) return 0.0;
    return totalReviews / numberOfReviews;
  }

  String get fullName => '$firstName $lastName';
}
