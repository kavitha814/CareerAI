import 'package:careerpilot_ai/models/user_profile.dart';
import 'package:careerpilot_ai/models/roadmap.dart';
import 'package:careerpilot_ai/models/chat_message.dart';

abstract class CareerRepository {
  Future<UserProfile?> getUserProfile(String userId);
  Future<void> saveUserProfile(UserProfile profile);
  
  Future<List<CareerRoadmap>> getRoadmaps(String userId);
  Future<CareerRoadmap?> getRoadmapById(String userId, String roadmapId);
  Future<void> saveRoadmap(String userId, CareerRoadmap roadmap);
  Future<void> updateRoadmapTaskCompletion(String userId, String roadmapId, String milestoneId, String taskId, bool isCompleted);

  Future<List<ChatMessageModel>> getChatHistory(String userId);
  Future<void> saveChatMessage(String userId, ChatMessageModel message);
  Future<void> clearChatHistory(String userId);
}
