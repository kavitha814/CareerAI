import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:careerpilot_ai/core/theme/app_theme.dart';
import 'package:careerpilot_ai/core/widgets/genui_catalog.dart';
import 'package:careerpilot_ai/core/services/gemini_service.dart';
import 'package:careerpilot_ai/providers/auth_provider.dart';
import 'package:careerpilot_ai/providers/career_provider.dart';
import 'package:careerpilot_ai/models/roadmap.dart';
import 'package:uuid/uuid.dart';

enum _ChatMsgKind { user, modelText, surface, error }

class _ChatMsgItem {
  _ChatMsgItem.user({required this.text}) : kind = _ChatMsgKind.user, surfaceId = null;
  _ChatMsgItem.modelText(this.text) : kind = _ChatMsgKind.modelText, surfaceId = null;
  _ChatMsgItem.surface(this.surfaceId) : kind = _ChatMsgKind.surface, text = null;
  _ChatMsgItem.error(this.text) : kind = _ChatMsgKind.error, surfaceId = null;

  final _ChatMsgKind kind;
  String? text;
  final String? surfaceId;
}

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  late final SurfaceController _surfaceController;
  late final GeminiService _geminiService;
  late final Conversation _conversation;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMsgItem> _items = [];
  final Set<String> _seenSurfaces = {};
  
  StreamSubscription<ConversationEvent>? _eventsSub;
  StreamSubscription<ChatMessage>? _submitSub;

  @override
  void initState() {
    super.initState();
    _surfaceController = SurfaceController(catalogs: [careerPilotCatalog]);
    _geminiService = GeminiService();
    _conversation = Conversation(
      controller: _surfaceController,
      transport: _geminiService.transport,
    );

    _eventsSub = _conversation.events.listen(_onEvent);
    _submitSub = _surfaceController.onSubmit.listen(_onUserSubmit);
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _submitSub?.cancel();
    _conversation.dispose();
    _geminiService.dispose();
    _surfaceController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUserSubmit(ChatMessage message) {
    // Parse user action details to show a bubble and save roadmaps
    final summary = _summarizeInteraction(message);
    if (summary != null) {
      setState(() => _items.add(_ChatMsgItem.user(text: summary)));
      _scrollToBottom();
    }
    _conversation.sendRequest(message);
  }

  String? _summarizeInteraction(ChatMessage message) {
    for (final part in message.parts) {
      if (!part.isUiInteractionPart) continue;
      try {
        final json = jsonDecode(part.asUiInteractionPart!.interaction) as Map<String, dynamic>;
        final action = json['action'] as Map<String, dynamic>?;
        final name = action?['name'] as String?;
        final contextData = action?['context'] as Map<String, dynamic>?;

        if (contextData == null) return null;

        // Custom action: Save roadmap to DB
        if (name == 'saveGeneratedRoadmap') {
          _saveRoadmap(contextData);
          return 'Save "${contextData['title']}" to Dashboard';
        }

        if (name == 'generateRoadmapForGap') {
          return 'Create Bridge Roadmap for "${contextData['target']}"';
        }

        if (name == 'requestPracticeFeedback') {
          return 'Evaluate my answer for: "${contextData['question']}"';
        }

        if (name == 'submitQuestionnaire') {
          final status = contextData['status'] ?? 'Student';
          final exp = contextData['experience'] ?? 'Beginner';
          final time = contextData['studyTime'] ?? '1-2 hours/day';
          return 'Status: $status • Experience: $exp • Study time: $time';
        }

        if (name == 'submitAnswer') {
          final selected = contextData['selectedOption'] ?? 'None';
          return '$selected';
        }

        if (contextData['label'] != null) {
          return 'Toggled: ${contextData['label']} (${contextData['completed'] == true ? 'Completed' : 'Todo'})';
        }

        return 'Selected an action';
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _saveRoadmap(Map<String, dynamic> data) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final title = data['title'] as String? ?? 'Career Path';
    final milestonesData = data['milestones'] as List<dynamic>? ?? [];

    final List<RoadmapMilestone> milestones = [];
    for (int i = 0; i < milestonesData.length; i++) {
      final m = milestonesData[i] as Map<String, dynamic>;
      final week = m['week'] ?? (i + 1);
      final mTitle = m['title'] ?? 'Milestone';
      final mDesc = m['description'] ?? 'Learn core topics.';
      final tasksData = m['tasks'] as List<dynamic>? ?? [];

      final List<RoadmapTask> tasks = [];
      for (int j = 0; j < tasksData.length; j++) {
        final taskTitle = tasksData[j].toString();
        
        // Generate YouTube Search URL based on task title, module name, career name, and preferred languages
        final languagesStr = user.preferredLanguages.isNotEmpty 
            ? user.preferredLanguages.join(' ') 
            : 'English';
        final query = '$taskTitle in $mTitle $title tutorial $languagesStr';
        final youtubeUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}';

        tasks.add(RoadmapTask(
          id: 't_${i}_$j',
          title: taskTitle,
          description: 'Learn and review',
          type: 'concept',
          resources: [youtubeUrl],
        ));
      }

      milestones.add(RoadmapMilestone(
        id: 'm_$i',
        weekNumber: week,
        title: mTitle,
        description: mDesc,
        tasks: tasks,
      ));
    }

    final roadmap = CareerRoadmap(
      id: const Uuid().v4(),
      title: title,
      description: 'AI Generated Career Roadmap for $title.',
      estimatedDuration: '${milestones.length} Weeks',
      milestones: milestones,
      createdAt: DateTime.now(),
    );

    // Save using repo
    await ref.read(careerRepositoryProvider).saveRoadmap(user.id, roadmap);
    
    // Set active roadmap path in user profile
    final updatedUser = user.copyWith(currentPath: title);
    await ref.read(authProvider.notifier).updateUserProfile(updatedUser);

    // Invalidate state to refresh dashboard
    ref.invalidate(roadmapsListProvider);
  }

  void _onEvent(ConversationEvent event) {
    switch (event) {
      case ConversationSurfaceAdded(:final surfaceId):
        if (_seenSurfaces.add(surfaceId)) {
          setState(() => _items.add(_ChatMsgItem.surface(surfaceId)));
          _scrollToBottom();
        }
      case ConversationContentReceived(:final text):
        final trimmed = text.trim();
        if (trimmed.isEmpty) break;
        setState(() {
          if (_items.isNotEmpty && _items.last.kind == _ChatMsgKind.modelText) {
            _items.last.text = '${_items.last.text} $trimmed'.trim();
          } else {
            _items.add(_ChatMsgItem.modelText(trimmed));
          }
        });
        _scrollToBottom();
      case ConversationError(:final error):
        setState(() => _items.add(_ChatMsgItem.error(error.toString())));
        _scrollToBottom();
      default:
        break;
    }
  }

  Future<void> _send() async {
    if (_conversation.state.value.isWaiting) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _items.add(_ChatMsgItem.user(text: text));
    });
    _textController.clear();
    _scrollToBottom();

    await _conversation.sendRequest(ChatMessage.user(text));
  }

  Future<void> _sendPromptDirectly(String text) async {
    if (_conversation.state.value.isWaiting) return;
    setState(() {
      _items.add(_ChatMsgItem.user(text: text));
    });
    _scrollToBottom();
    await _conversation.sendRequest(ChatMessage.user(text));
  }

  int _countAnswers() {
    int count = 0;
    for (final item in _items) {
      if (item.kind == _ChatMsgKind.user && item.text != null && item.text!.startsWith('Answered:')) {
        count++;
      }
    }
    return count;
  }

  String _getWaitingMessage() {
    final answers = _countAnswers();
    switch (answers) {
      case 0:
        return 'Analyzing career path & generating assessment questions...';
      case 1:
        return 'Processing answer & preparing next assessment question...';
      case 2:
        return 'Processing answer & preparing final assessment question...';
      case 3:
      default:
        return 'Synthesizing answers & generating your personalized roadmap...';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen<String?>(chatPromptProvider, (previous, next) {
      if (next != null && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _sendPromptDirectly(next);
        });
        ref.read(chatPromptProvider.notifier).state = null;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text('Career Mentor AI', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Personalized paths and Prep Coach', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _items.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _items.length,
                      itemBuilder: (context, i) => _buildChatItem(_items[i], theme),
                    ),
            ),
            ValueListenableBuilder<ConversationState>(
              valueListenable: _conversation.state,
              builder: (context, state, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isWaiting)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0, left: 16.0, right: 16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.12),
                                AppTheme.secondaryColor.withOpacity(0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: theme.brightness == Brightness.dark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Lottie.asset(
                                      'lib/assets/loading_ai.json',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              AppTheme.primaryColor,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Career Pilot AI',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getWaitingMessage(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    _buildComposer(state.isWaiting, theme),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 48, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              'Ask for a Career Path',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell me what role you want to achieve or what skills you want to learn. E.g. "I want to become a Flutter Developer in 4 months".',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(_ChatMsgItem item, ThemeData theme) {
    switch (item.kind) {
      case _ChatMsgKind.user:
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12, left: 48),
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Text(
              item.text ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        );

      case _ChatMsgKind.modelText:
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12, right: 48),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? const Color(0xFF111827) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.06)),
            ),
            child: Text(
              item.text ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        );

      case _ChatMsgKind.surface:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Surface(
            surfaceContext: _surfaceController.contextFor(item.surfaceId!),
          ),
        );

      case _ChatMsgKind.error:
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Text(
            item.text ?? 'Error occurred.',
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        );
    }
  }

  Widget _buildComposer(bool isBusy, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark ? const Color(0xFF111827) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.06)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textController,
                enabled: !isBusy,
                decoration: const InputDecoration(
                  hintText: 'Ask your career mentor...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            child: IconButton(
              icon: const Icon(Icons.arrow_upward, color: Colors.white),
              onPressed: isBusy ? null : _send,
            ),
          ),
        ],
      ),
    );
  }
}
