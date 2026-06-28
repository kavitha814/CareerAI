import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:careerpilot_ai/models/chat_message.dart';
import 'package:careerpilot_ai/models/roadmap.dart';
import 'package:careerpilot_ai/models/user_profile.dart';
import 'package:careerpilot_ai/repositories/career_repository.dart';

class FirebaseCareerRepository implements CareerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol => _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> _roadmapsCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('roadmaps');

  CollectionReference<Map<String, dynamic>> _chatsCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('chats');

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _usersCol.doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await _usersCol.doc(profile.id).set(profile.toMap());
    } catch (_) {}
  }

  @override
  Future<List<CareerRoadmap>> getRoadmaps(String userId) async {
    try {
      final snapshot = await _roadmapsCol(userId).orderBy('createdAt', descending: true).get();
      return snapshot.docs.map((doc) => CareerRoadmap.fromMap(doc.data())).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<CareerRoadmap?> getRoadmapById(String userId, String roadmapId) async {
    try {
      final doc = await _roadmapsCol(userId).doc(roadmapId).get();
      if (!doc.exists || doc.data() == null) return null;
      return CareerRoadmap.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveRoadmap(String userId, CareerRoadmap roadmap) async {
    try {
      await _roadmapsCol(userId).doc(roadmap.id).set(roadmap.toMap());
    } catch (_) {}
  }

  @override
  Future<void> updateRoadmapTaskCompletion(
    String userId,
    String roadmapId,
    String milestoneId,
    String taskId,
    bool isCompleted,
  ) async {
    try {
      final roadmap = await getRoadmapById(userId, roadmapId);
      if (roadmap == null) return;

      final updatedMilestones = roadmap.milestones.map((m) {
        if (m.id == milestoneId) {
          final updatedTasks = m.tasks.map((t) {
            if (t.id == taskId) {
              return t.copyWith(isCompleted: isCompleted);
            }
            return t;
          }).toList();
          return RoadmapMilestone(
            id: m.id,
            weekNumber: m.weekNumber,
            title: m.title,
            description: m.description,
            tasks: updatedTasks,
          );
        }
        return m;
      }).toList();

      final updatedRoadmap = roadmap.copyWith(milestones: updatedMilestones);
      await saveRoadmap(userId, updatedRoadmap);
    } catch (_) {}
  }

  @override
  Future<List<ChatMessageModel>> getChatHistory(String userId) async {
    try {
      final snapshot = await _chatsCol(userId).orderBy('timestamp', descending: false).get();
      return snapshot.docs.map((doc) => ChatMessageModel.fromMap(doc.data())).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveChatMessage(String userId, ChatMessageModel message) async {
    try {
      await _chatsCol(userId).doc(message.id).set(message.toMap());
    } catch (_) {}
  }

  @override
  Future<void> clearChatHistory(String userId) async {
    try {
      final snapshot = await _chatsCol(userId).get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }
}
