class ChatMessageModel {
  final String id;
  final String sender; // 'user' or 'model'
  final String? text;
  final String? surfaceId;
  final DateTime timestamp;
  final bool isUiResponse;

  ChatMessageModel({
    required this.id,
    required this.sender,
    this.text,
    this.surfaceId,
    required this.timestamp,
    this.isUiResponse = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'surfaceId': surfaceId,
      'timestamp': timestamp.toIso8601String(),
      'isUiResponse': isUiResponse,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] ?? '',
      sender: map['sender'] ?? 'user',
      text: map['text'],
      surfaceId: map['surfaceId'],
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      isUiResponse: map['isUiResponse'] ?? false,
    );
  }
}
