import 'dart:convert';
import 'package:careerpilot_ai/models/chat_message.dart';
import 'package:careerpilot_ai/models/roadmap.dart';
import 'package:careerpilot_ai/models/user_profile.dart';
import 'package:careerpilot_ai/repositories/career_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveCareerRepository implements CareerRepository {
  static const String _userBoxName = 'user_profiles_box';
  static const String _roadmapsBoxName = 'roadmaps_box';
  static const String _chatsBoxName = 'chats_box';

  Future<void> init() async {
    await Hive.openBox(_userBoxName);
    await Hive.openBox(_roadmapsBoxName);
    await Hive.openBox(_chatsBoxName);
  }

  Box get _userBox => Hive.box(_userBoxName);
  Box get _roadmapsBox => Hive.box(_roadmapsBoxName);
  Box get _chatsBox => Hive.box(_chatsBoxName);

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    final data = _userBox.get(userId);
    if (data == null) return null;
    final Map<String, dynamic> map = Map<String, dynamic>.from(jsonDecode(data as String));
    return UserProfile.fromMap(map);
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    final data = jsonEncode(profile.toMap());
    await _userBox.put(profile.id, data);
  }

  @override
  Future<List<CareerRoadmap>> getRoadmaps(String userId) async {
    final List<CareerRoadmap> list = [];
    final keys = _roadmapsBox.keys.where((k) => k.toString().startsWith('${userId}_'));
    for (var key in keys) {
      final data = _roadmapsBox.get(key);
      if (data != null) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(jsonDecode(data as String));
        list.add(CareerRoadmap.fromMap(map));
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<CareerRoadmap?> getRoadmapById(String userId, String roadmapId) async {
    final data = _roadmapsBox.get('${userId}_$roadmapId');
    if (data == null) return null;
    final Map<String, dynamic> map = Map<String, dynamic>.from(jsonDecode(data as String));
    return CareerRoadmap.fromMap(map);
  }

  @override
  Future<void> saveRoadmap(String userId, CareerRoadmap roadmap) async {
    final data = jsonEncode(roadmap.toMap());
    await _roadmapsBox.put('${userId}_${roadmap.id}', data);
  }

  @override
  Future<void> updateRoadmapTaskCompletion(
    String userId,
    String roadmapId,
    String milestoneId,
    String taskId,
    bool isCompleted,
  ) async {
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
  }

  @override
  Future<List<ChatMessageModel>> getChatHistory(String userId) async {
    final data = _chatsBox.get(userId);
    if (data == null) return [];
    final List<dynamic> rawList = jsonDecode(data as String);
    return rawList.map((x) => ChatMessageModel.fromMap(Map<String, dynamic>.from(x))).toList();
  }

  @override
  Future<void> saveChatMessage(String userId, ChatMessageModel message) async {
    final history = await getChatHistory(userId);
    history.add(message);
    final data = jsonEncode(history.map((e) => e.toMap()).toList());
    await _chatsBox.put(userId, data);
  }

  @override
  Future<void> clearChatHistory(String userId) async {
    await _chatsBox.delete(userId);
  }
}
