class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? currentPath;
  final List<String> currentSkills;
  final List<String> targetSkills;
  final int streak;
  final int roadmapsCompleted;
  final int certificatesCount;
  final int aiUsageCount;
  final bool isGuest;
  final int age;
  final List<String> preferredLanguages;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.currentPath,
    required this.currentSkills,
    required this.targetSkills,
    required this.streak,
    required this.roadmapsCompleted,
    required this.certificatesCount,
    required this.aiUsageCount,
    this.isGuest = false,
    required this.age,
    required this.preferredLanguages,
  });

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? currentPath,
    List<String>? currentSkills,
    List<String>? targetSkills,
    int? streak,
    int? roadmapsCompleted,
    int? certificatesCount,
    int? aiUsageCount,
    bool? isGuest,
    int? age,
    List<String>? preferredLanguages,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      currentPath: currentPath ?? this.currentPath,
      currentSkills: currentSkills ?? this.currentSkills,
      targetSkills: targetSkills ?? this.targetSkills,
      streak: streak ?? this.streak,
      roadmapsCompleted: roadmapsCompleted ?? this.roadmapsCompleted,
      certificatesCount: certificatesCount ?? this.certificatesCount,
      aiUsageCount: aiUsageCount ?? this.aiUsageCount,
      isGuest: isGuest ?? this.isGuest,
      age: age ?? this.age,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'currentPath': currentPath,
      'currentSkills': currentSkills,
      'targetSkills': targetSkills,
      'streak': streak,
      'roadmapsCompleted': roadmapsCompleted,
      'certificatesCount': certificatesCount,
      'aiUsageCount': aiUsageCount,
      'isGuest': isGuest,
      'age': age,
      'preferredLanguages': preferredLanguages,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      currentPath: map['currentPath'],
      currentSkills: List<String>.from(map['currentSkills'] ?? []),
      targetSkills: List<String>.from(map['targetSkills'] ?? []),
      streak: map['streak'] ?? 0,
      roadmapsCompleted: map['roadmapsCompleted'] ?? 0,
      certificatesCount: map['certificatesCount'] ?? 0,
      aiUsageCount: map['aiUsageCount'] ?? 0,
      isGuest: map['isGuest'] ?? false,
      age: map['age'] ?? 18,
      preferredLanguages: List<String>.from(map['preferredLanguages'] ?? ['English']),
    );
  }
}
