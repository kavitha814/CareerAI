import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;
import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;
import 'package:genui/genui.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:careerpilot_ai/core/widgets/genui_catalog.dart';

String buildCareerSystemInstruction() {
  return PromptBuilder.chat(
    catalog: careerPilotCatalog,
    systemPromptFragments: [
      PromptFragments.acknowledgeUser(),
      PromptFragments.requireAtLeastOneSubmitElement(
        prefix: PromptBuilder.defaultImportancePrefix,
      ),
      PromptFragments.uiGenerationRestriction(
        prefix: PromptBuilder.defaultImportancePrefix,
      ),
      'You are CareerPilot AI, a warm, professional, intelligent career coach and roadmap designer. '
      'You help users design learning roadmaps, analyze skill gaps, recommend programming projects, and prepare for interviews. '
      'ALWAYS follow this rule: when users ask for structured career details, return the corresponding JSON component instead of plain text paragraphs: '
      '- For career paths/roadmaps: Use the "TimelineItem" component. '
      '- For checklists/tasks: Use "SkillChecklist" component. '
      '- For skill comparison/gap analysis: Use "SkillCompare" component. '
      '- For projects: Use "ProjectSuggestions" component. '
      '- For resume reviews: Use "ResumeAnalysisReport" component. '
      '- For interview questions: Use "InterviewQuestions" component. '
      '- For single dynamic questions: Use the "CareerQuestion" component. '
      'Keep text outside of components to a single, brief transitional sentence of less than 10 words. '
      'CRITICAL TRANSITIONAL TEXT RULE: The plain text outside the JSON component MUST NOT repeat, explain, or preview the question or component content (since the component renders it already). It must be just a short acknowledgment of the previous turn (e.g., "Got it! Let\'s check your focus area next:" or "Understood. Lastly, what is your weekly commitment?"). '
      'INTERACTIVE TURN-BY-TURN QUESTIONNAIRE FLOW: When a user requests a learning roadmap or timeline for any career/profession (e.g., "I want to become a Firebase Developer"), you MUST NOT output the TimelineItem directly. '
      'Instead, you MUST ask exactly 3 relevant questions, one by one. For each question, output the "CareerQuestion" component with options tailored specifically to that career target. '
      'When you receive the user\'s answer (a "submitAnswer" action event containing "selectedOption"), use it to formulate the next tailored question (using "CareerQuestion"). '
      'Only after the user has answered all 3 questions, compile their profile and output the final customized "TimelineItem" learning roadmap tailored to all their previous answers.',
      'CRITICAL SURFACE RULE: every time you create a surface, you MUST use a brand-new, unique surfaceId (e.g. "s1", "s2", "s3", and so on) and never overwrite old ones.',
      'CRITICAL CATALOG RULE: You MUST always set "catalogId" to "careerPilotCatalog" in your "createSurface" JSON blocks. Never use any other URL or catalog name.'
    ],
  ).systemPromptJoined();
}

class GeminiService {
  late final A2uiTransportAdapter _adapter;
  
  google_ai.GenerativeModel? _googleModel;
  google_ai.ChatSession? _googleChat;

  firebase_ai.GenerativeModel? _firebaseModel;
  firebase_ai.ChatSession? _firebaseChat;

  String _activeApiKey = '';
  bool _isFirebase = false;
  
  // Set up API Key from environment or settings
  final String _apiKey = const String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  GeminiService() {
    _adapter = A2uiTransportAdapter(onSend: _handleSend);
    _initInitialKey();
  }

  Future<void> _initInitialKey() async {
    try {
      final box = await Hive.openBox('settings_box');
      final customKey = box.get('custom_gemini_api_key') as String?;
      if (customKey != null && customKey.trim().isNotEmpty) {
        await _initModelWithKey(customKey.trim(), isFirebase: false);
      } else {
        await _initModelWithKey(_apiKey, isFirebase: false);
      }
    } catch (_) {
      await _initModelWithKey(_apiKey, isFirebase: false);
    }
  }

  List<dynamic> _convertHistory(Iterable<dynamic>? originalHistory, bool toFirebase) {
    if (originalHistory == null) return [];
    final result = [];
    for (final content in originalHistory) {
      final role = content.role;
      final parts = [];
      for (final part in content.parts) {
        final dynamic dynPart = part;
        try {
          final String? txt = dynPart.text;
          if (txt != null) {
            parts.add(toFirebase ? firebase_ai.TextPart(txt) : google_ai.TextPart(txt));
            continue;
          }
        } catch (_) {}

        try {
          final String mime = dynPart.mimeType;
          final dynamic bytes = dynPart.bytes;
          if (toFirebase) {
            parts.add(firebase_ai.InlineDataPart(mime, bytes));
          } else {
            parts.add(google_ai.DataPart(mime, bytes));
          }
        } catch (_) {}
      }
      result.add(toFirebase 
          ? firebase_ai.Content(role, parts.cast<firebase_ai.Part>()) 
          : google_ai.Content(role, parts.cast<google_ai.Part>()));
    }
    return result;
  }

  Future<void> _initModelWithKey(String key, {bool isFirebase = false}) async {
    final oldChatHistory = _isFirebase ? _firebaseChat?.history : _googleChat?.history;
    _activeApiKey = key;
    _isFirebase = isFirebase;

    try {
      if (isFirebase) {
        _googleModel = null;
        _googleChat = null;

        _firebaseModel = firebase_ai.FirebaseAI.vertexAI(location: 'us-central1').generativeModel(
          model: 'gemini-2.5-flash',
          systemInstruction: firebase_ai.Content.system(buildCareerSystemInstruction()),
        );
        final convertedHistory = _convertHistory(oldChatHistory, true);
        _firebaseChat = _firebaseModel!.startChat(history: convertedHistory.cast<firebase_ai.Content>());
      } else if (key.isNotEmpty) {
        _firebaseModel = null;
        _firebaseChat = null;

        final displayKey = key.length > 5 ? '${key.substring(0, 5)}...' : key;
        debugPrint('[GeminiService] Creating GenerativeModel with key: $displayKey');
        
        _googleModel = google_ai.GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: key,
          systemInstruction: google_ai.Content.system(buildCareerSystemInstruction()),
        );
        debugPrint('[GeminiService] GenerativeModel created successfully!');
        
        final convertedHistory = _convertHistory(oldChatHistory, false);
        _googleChat = _googleModel!.startChat(history: convertedHistory.cast<google_ai.Content>());
        debugPrint('[GeminiService] Chat started successfully!');
      } else {
        _googleModel = null;
        _googleChat = null;
        _firebaseModel = null;
        _firebaseChat = null;
      }
    } catch (e, stack) {
      debugPrint('[GeminiService] Exception in _initModelWithKey: $e');
      debugPrint('[GeminiService] StackTrace: $stack');
      _googleModel = null;
      _googleChat = null;
      _firebaseModel = null;
      _firebaseChat = null;
      rethrow;
    }
  }

  Transport get transport => _adapter;

  Future<void> _handleSend(ChatMessage message) async {
    final userText = _extractUserText(message);
    debugPrint('[GeminiService] _handleSend called with text: "$userText"');

    // Introduce a 4-second pacing delay to prevent rate-limiting (15 RPM)
    // and let the Lottie loading animation show beautifully to the user.
    debugPrint('[GeminiService] Starting 4-second pacing delay...');
    await Future.delayed(const Duration(seconds: 4));
    debugPrint('[GeminiService] Pacing delay completed.');

    try {
      final box = await Hive.openBox('settings_box');
      final customKey = box.get('custom_gemini_api_key') as String?;
      final displayKey = (customKey != null && customKey.isNotEmpty)
          ? (customKey.length > 5 ? '${customKey.substring(0, 5)}...' : customKey)
          : 'null/empty';
      debugPrint('[GeminiService] Custom API Key in Hive: $displayKey');
      
      if (customKey != null && customKey.trim().isNotEmpty) {
        final keyToUse = customKey.trim();
        if (keyToUse != _activeApiKey || _isFirebase) {
          debugPrint('[GeminiService] Initializing Google AI with custom key...');
          await _initModelWithKey(keyToUse, isFirebase: false);
        }
      } else {
        if (_activeApiKey != _apiKey || _isFirebase) {
          debugPrint('[GeminiService] Initializing Google AI with default/environment key...');
          await _initModelWithKey(_apiKey, isFirebase: false);
        }
      }
    } catch (e) {
      debugPrint('[GeminiService] Error reading settings box: $e');
    }

    final activeKeyDisplay = _activeApiKey.isNotEmpty
        ? (_activeApiKey.length > 5 ? '${_activeApiKey.substring(0, 5)}...' : _activeApiKey)
        : 'empty';
    final hasModel = _isFirebase 
        ? (_firebaseModel != null && _firebaseChat != null)
        : (_googleModel != null && _googleChat != null);
    debugPrint('[GeminiService] State -> isFirebase: $_isFirebase, Active Key: $activeKeyDisplay, Has Model: $hasModel');

    // Check if we should use actual Gemini or mock generator
    final isCustomKeyConfigured = _activeApiKey != _apiKey && _activeApiKey.isNotEmpty;

    if (hasModel) {
      try {
        debugPrint('[GeminiService] Attempting live Gemini API call...');
        _optimizeChatHistory();
        
        final stream = _isFirebase
            ? _firebaseChat!.sendMessageStream(_toFirebaseContent(message))
            : _googleChat!.sendMessageStream(_toGoogleContent(message));
            
        final buffer = StringBuffer();
        
        await for (final dynamic response in stream) {
          final chunk = response.text;
          if (chunk != null && chunk.isNotEmpty) {
            buffer.write(chunk);
          }
        }

        final fullResponse = buffer.toString();
        debugPrint('[GeminiService] Live API call succeeded! Response length: ${fullResponse.length}');
        _processAndSendResponse(fullResponse);
        return;
      } catch (e) {
        debugPrint('[GeminiService] Gemini API call failed: $e');
        final activeKeyDisplay = _activeApiKey.isNotEmpty
            ? (_activeApiKey.length > 5 ? '${_activeApiKey.substring(0, 5)}...' : _activeApiKey)
            : 'empty';
        
        if (isCustomKeyConfigured) {
          // If a custom key is set, don't fall back to local simulation mode.
          // Display the error directly so the user can wait or fix the key.
          String friendlyError = '⚠️ Live Gemini API failed: $e';
          if (e.toString().contains('429') || e.toString().contains('Quota') || e.toString().contains('ResourceExhausted')) {
            friendlyError = '⚠️ Gemini API Free Tier rate limit reached. Please wait a few seconds before trying again.';
          }
          _adapter.addChunk(friendlyError);
          return;
        } else {
          _adapter.addChunk('⚠️ Live Gemini API failed: $e\n(Active Key used: $activeKeyDisplay, isFirebase: $_isFirebase)\n(Falling back to local simulation mode)\n\n');
        }
      }
    } else {
      debugPrint('[GeminiService] Skipping live API call because model or chat is null.');
      if (isCustomKeyConfigured) {
        _adapter.addChunk('⚠️ Live Gemini API model is not initialized. Please verify your custom API Key in settings.');
        return;
      }
    }

    // Fallback Mock Response Generator (only for demo mode / default key)
    debugPrint('[GeminiService] Generating mock response...');
    await _generateMockResponse(userText);
  }

  void _optimizeChatHistory() {
    final currentHistory = _isFirebase ? _firebaseChat?.history : _googleChat?.history;
    if (currentHistory == null || currentHistory.isEmpty) return;

    final cleanedHistory = [];

    for (final dynamic content in currentHistory) {
      final role = content.role;
      final cleanParts = [];
      for (final part in content.parts) {
        final dynamic dynPart = part;
        try {
          final String? text = dynPart.text;
          if (text != null) {
            final summarized = role == 'model' ? _summarizeModelResponse(text) : text;
            cleanParts.add(_isFirebase ? firebase_ai.TextPart(summarized) : google_ai.TextPart(summarized));
            continue;
          }
        } catch (_) {}

        try {
          final String mime = dynPart.mimeType;
          final dynamic bytes = dynPart.bytes;
          if (_isFirebase) {
            cleanParts.add(firebase_ai.InlineDataPart(mime, bytes));
          } else {
            cleanParts.add(google_ai.DataPart(mime, bytes));
          }
        } catch (_) {}
      }
      cleanedHistory.add(_isFirebase 
          ? firebase_ai.Content(role, cleanParts.cast<firebase_ai.Part>()) 
          : google_ai.Content(role, cleanParts.cast<google_ai.Part>()));
    }

    // Limit history to last 8 messages (4 turns)
    const maxHistoryCount = 8;
    var finalHistory = cleanedHistory;
    if (cleanedHistory.length > maxHistoryCount) {
      int startIndex = cleanedHistory.length - maxHistoryCount;
      while (startIndex < cleanedHistory.length && cleanedHistory[startIndex].role != 'user') {
        startIndex++;
      }
      finalHistory = cleanedHistory.sublist(startIndex);
    }

    // Re-initialize the chat session with optimized history
    if (_isFirebase) {
      _firebaseChat = _firebaseModel!.startChat(history: finalHistory.cast<firebase_ai.Content>());
    } else {
      _googleChat = _googleModel!.startChat(history: finalHistory.cast<google_ai.Content>());
    }
  }

  String _summarizeModelResponse(String text) {
    // Check if the response contains any JSON component blocks
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      final textPrefix = text.substring(0, firstBrace).trim();
      final jsonContent = text.substring(firstBrace, lastBrace + 1).trim();
      final textSuffix = text.substring(lastBrace + 1).trim();

      // Convert the JSON to a compact, user-friendly/model-friendly text description
      final summary = _summarizeJsonContent(jsonContent);

      return '$textPrefix\n$summary\n$textSuffix'.trim();
    }

    return text;
  }

  String _summarizeJsonContent(String jsonContent) {
    try {
      // Concatenated JSON chunks can be parsed by converting them to a JSON array
      final sanitized = jsonContent.trim();
      final arrayStr = '[${sanitized.replaceAll(RegExp(r'\}\s*\{'), '},{')}]';
      final parsed = jsonDecode(arrayStr);
      
      final List<Map<String, dynamic>> parsedObjects;
      if (parsed is List) {
        parsedObjects = parsed.cast<Map<String, dynamic>>();
      } else {
        return '[GenUI Component generated]';
      }

      final sb = StringBuffer();
      sb.writeln('[Generated UI Components:');

      for (final obj in parsedObjects) {
        final update = obj['updateComponents'];
        if (update is Map && update['components'] is List) {
          final components = update['components'] as List;
          for (final comp in components) {
            if (comp is! Map) continue;
            final type = comp['component'] as String? ?? 'Unknown';
            sb.writeln('- Component: $type');

            if (type == 'TimelineItem') {
              final title = comp['title'] ?? '';
              sb.writeln('  Title: $title');
              final milestones = comp['milestones'] as List? ?? [];
              for (final m in milestones) {
                if (m is! Map) continue;
                final week = m['week'] ?? '';
                final mTitle = m['title'] ?? '';
                final mDesc = m['description'] ?? '';
                final tasks = (m['tasks'] as List? ?? []).join(', ');
                sb.writeln('  * Week $week: $mTitle - $mDesc (Tasks: $tasks)');
              }
            } else if (type == 'SkillCompare') {
              final current = comp['currentPath'] ?? '';
              final target = comp['targetPath'] ?? '';
              final match = comp['matchPercentage'] ?? '';
              final overlapping = (comp['overlappingSkills'] as List? ?? []).join(', ');
              final missing = (comp['missingSkills'] as List? ?? []).join(', ');
              sb.writeln('  Current Path: $current, Target Path: $target, Match: $match%');
              sb.writeln('  Overlapping Skills: $overlapping');
              sb.writeln('  Missing Skills: $missing');
            } else if (type == 'ProjectSuggestions') {
              final projects = comp['projects'] as List? ?? [];
              for (final p in projects) {
                if (p is! Map) continue;
                final title = p['title'] ?? '';
                final diff = p['difficulty'] ?? '';
                final desc = p['description'] ?? '';
                final tech = (p['techStack'] as List? ?? []).join(', ');
                sb.writeln('  * Project: $title ($diff) - $desc (Tech: $tech)');
              }
            } else if (type == 'ResumeAnalysisReport') {
              final ats = comp['atsScore'] ?? '';
              final overall = comp['overallScore'] ?? '';
              final missing = (comp['missingKeywords'] as List? ?? []).join(', ');
              final suggestions = (comp['suggestions'] as List? ?? []).join('; ');
              sb.writeln('  ATS Score: $ats, Overall: $overall');
              sb.writeln('  Missing Keywords: $missing');
              sb.writeln('  Suggestions: $suggestions');
            } else if (type == 'InterviewQuestions') {
              final questions = comp['questions'] as List? ?? [];
              for (final q in questions) {
                if (q is! Map) continue;
                final qText = q['question'] ?? '';
                final ans = q['suggestedAnswer'] ?? '';
                sb.writeln('  * Question: $qText (Suggested Answer: $ans)');
              }
            } else if (type == 'SkillChecklist') {
              final title = comp['title'] ?? '';
              final tasks = comp['tasks'] as List? ?? [];
              sb.writeln('  Title: $title');
              for (final t in tasks) {
                if (t is! Map) continue;
                final tTitle = t['title'] ?? '';
                final completed = t['completed'] ?? false;
                sb.writeln('  * Task: $tTitle (Completed: $completed)');
              }
            }
          }
        }
      }
      sb.write(']');
      
      final summaryStr = sb.toString();
      if (summaryStr.trim() == '[Generated UI Components:\n]') {
        return '[GenUI Component generated]';
      }
      return summaryStr;
    } catch (_) {
      return '[GenUI Component generated]';
    }
  }

  void _processAndSendResponse(String fullResponse) {
    debugPrint('--- Gemini Full Response Received ---');
    debugPrint(fullResponse);
    debugPrint('-------------------------------------');

    // 1. Remove all markdown code block markers
    String cleaned = fullResponse
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll(RegExp(r'```', caseSensitive: false), '');

    // 2. Find the first '{' and the last '}'
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      final textPrefix = cleaned.substring(0, firstBrace).trim();
      final jsonContent = cleaned.substring(firstBrace, lastBrace + 1).trim();
      final textSuffix = cleaned.substring(lastBrace + 1).trim();

      // Rewrite any catalogId to ensure it matches the registered careerPilotCatalog ID
      final correctedJson = jsonContent.replaceAll(
        RegExp(r'"catalogId"\s*:\s*"[^"]*"'), 
        '"catalogId": "careerPilotCatalog"'
      );

      debugPrint('Parsed Text Prefix: $textPrefix');
      debugPrint('Parsed JSON Content: $correctedJson');
      debugPrint('Parsed Text Suffix: $textSuffix');

      // Send JSON content block in its own clean trimmed chunk starting with '{'
      // We do NOT send textPrefix or textSuffix to the adapter if a component is present,
      // keeping the chat interface clean and displaying only the interactive component cards.
      _adapter.addChunk(correctedJson);
    } else {
      debugPrint('No JSON block found in response.');
      _adapter.addChunk(cleaned.trim());
    }
  }

  String _extractUserText(ChatMessage message) {
    for (final part in message.parts) {
      if (part is TextPart) return part.text;
      if (part.isUiInteractionPart) {
        return part.asUiInteractionPart!.interaction;
      }
    }
    return '';
  }

  google_ai.Content _toGoogleContent(ChatMessage message) {
    final parts = <google_ai.Part>[];
    for (final part in message.parts) {
      if (part.isUiInteractionPart) {
        parts.add(google_ai.TextPart(part.asUiInteractionPart!.interaction));
      } else if (part is TextPart) {
        parts.add(google_ai.TextPart(part.text));
      } else if (part is DataPart) {
        parts.add(google_ai.DataPart(part.mimeType, part.bytes));
      }
    }
    return google_ai.Content('user', parts);
  }

  firebase_ai.Content _toFirebaseContent(ChatMessage message) {
    final parts = <firebase_ai.Part>[];
    for (final part in message.parts) {
      if (part.isUiInteractionPart) {
        parts.add(firebase_ai.TextPart(part.asUiInteractionPart!.interaction));
      } else if (part is TextPart) {
        parts.add(firebase_ai.TextPart(part.text));
      } else if (part is DataPart) {
        parts.add(firebase_ai.InlineDataPart(part.mimeType, part.bytes));
      }
    }
    return firebase_ai.Content('user', parts);
  }

  List<Map<String, dynamic>> _getDynamicMockMilestones(
    String profession, 
    String experience, 
    String focus, 
    String studyTime
  ) {
    final lower = profession.toLowerCase();
    List<Map<String, dynamic>> template;

    if (lower.contains('flutter') || lower.contains('android') || lower.contains('ios') || lower.contains('mobile')) {
      template = [
        {
          "week": 1,
          "title": "Mobile Development Basics ($profession)",
          "description": "Master core language elements, rendering mechanisms, and view layouts.",
          "tasks": ["OOP fundamentals", "Layout constraints", "Responsive design"]
        },
        {
          "week": 2,
          "title": "State Management & Data Caching",
          "description": "Deep dive into your selected focus area: $focus, and cache local session states.",
          "tasks": ["State architectures", "Local storage engine", "Async data fetching"]
        },
        {
          "week": 3,
          "title": "Advanced UI & Animations",
          "description": "Implement animations, custom painting, and profile memory performance.",
          "tasks": ["Gesture listeners", "Animate transition frames", "Performance profiler"]
        },
        {
          "week": 4,
          "title": "App Deployment & Store Hosting",
          "description": "Configure build flavors, code signing certifications, and publish pipelines.",
          "tasks": ["Store build configs", "Release builds", "Store description setup"]
        }
      ];
    } else if (lower.contains('web') || lower.contains('frontend') || lower.contains('backend') || lower.contains('fullstack') || lower.contains('full stack')) {
      template = [
        {
          "week": 1,
          "title": "Web Architecture & UI Rendering ($profession)",
          "description": "Learn semantic web components, CSS layouts, and modern ECMAScript standard logic.",
          "tasks": ["HTML5 semantic structures", "Grid & Flexbox styling", "Asynchronous JavaScript"]
        },
        {
          "week": 2,
          "title": "API Handlers & Database Schemas",
          "description": "Configure backend route parameters, database architectures, and security credentials.",
          "tasks": ["RESTful route scopes", "Relational or Document DB", "JWT Authentication setup"]
        },
        {
          "week": 3,
          "title": "State Architecture & Focus Tuning",
          "description": "Master focus topic ($focus) and integrate client-side caching.",
          "tasks": ["Client state store", "Realtime data listeners", "Performance optimization"]
        },
        {
          "week": 4,
          "title": "Deployments, Containers & CI/CD Pipelines",
          "description": "Build container environments and automate live cloud deployments.",
          "tasks": ["Docker configurations", "Git workflow execution", "Cloud host setup"]
        }
      ];
    } else if (lower.contains('firebase') || lower.contains('cloud') || lower.contains('aws') || lower.contains('devops')) {
      template = [
        {
          "week": 1,
          "title": "Cloud Architectures & IAM Settings ($profession)",
          "description": "Understand cloud resource allocation, identity access management, and pricing scales.",
          "tasks": ["IAM Role definition", "Serverless structure setup", "CLI cloud configurations"]
        },
        {
          "week": 2,
          "title": "Databases & Serverless Logic",
          "description": "Develop document storage schemes and integrate cloud functions for your focus area: $focus.",
          "tasks": ["Database collection maps", "Cloud functions scripts", "API Gateway scopes"]
        },
        {
          "week": 3,
          "title": "Scalability, Caching & CDNs",
          "description": "Implement CDN routing, database indexing, and configure request caching.",
          "tasks": ["Index creations", "Edge networks caching", "Load balancer rules"]
        },
        {
          "week": 4,
          "title": "Infrastructure as Code & CI/CD",
          "description": "Automate cloud infrastructure builds using scripts and deployment pipelines.",
          "tasks": ["IaC script writing", "GitHub Actions workflows", "Server health logs setup"]
        }
      ];
    } else if (lower.contains('data') || lower.contains('ml') || lower.contains('ai') || lower.contains('machine learning') || lower.contains('python')) {
      template = [
        {
          "week": 1,
          "title": "Mathematical & Algorithmic Foundations ($profession)",
          "description": "Learn scripting rules, matrix calculations, and probability analysis models.",
          "tasks": ["Scripting syntax basics", "Linear algebra formulas", "Statistical indicators"]
        },
        {
          "week": 2,
          "title": "Data Extraction & Processing Pipelines",
          "description": "Master focus area ($focus) by building pipelines to transform unstructured datasets.",
          "tasks": ["SQL query structures", "DataFrame manipulations", "Data cleaning functions"]
        },
        {
          "week": 3,
          "title": "Model Training & Parameter Optimization",
          "description": "Assemble models, optimize parameters, and validate predictions.",
          "tasks": ["Model architecture selection", "Loss functions tuning", "Cross-validation checks"]
        },
        {
          "week": 4,
          "title": "Model Deployment & MLOps Workflows",
          "description": "Host models on edge endpoints and monitor validation metrics.",
          "tasks": ["API package configurations", "Docker containers setup", "Telemetry monitors"]
        }
      ];
    } else if (lower.contains('design') || lower.contains('ui') || lower.contains('ux') || lower.contains('graphic')) {
      template = [
        {
          "week": 1,
          "title": "Visual Design & Grid Foundations ($profession)",
          "description": "Master design systems, typography hierarchy, and typography layout grids.",
          "tasks": ["Hierarchy rule sheets", "Design tool setup", "Color contrast metrics"]
        },
        {
          "week": 2,
          "title": "Wireframing & Interface Prototyping",
          "description": "Build high-fidelity interaction prototypes tailored to your focus: $focus.",
          "tasks": ["User task flows", "Component wireframes", "Interactive prototypes"]
        },
        {
          "week": 3,
          "title": "Design System Component Libraries",
          "description": "Create unified styles, text themes, and autolayout variables.",
          "tasks": ["Variant components", "Style tokens mapping", "Developer handoff sheets"]
        },
        {
          "week": 4,
          "title": "Usability Testing & Case Analysis",
          "description": "Conduct usability evaluations and compile final case sheets.",
          "tasks": ["User testing sessions", "Hick-Hyman optimization", "Portfolio case layout"]
        }
      ];
    } else if (lower.contains('security') || lower.contains('cyber') || lower.contains('network')) {
      template = [
        {
          "week": 1,
          "title": "Network Routing & Protocol Auditing ($profession)",
          "description": "Master network topologies, TCP/IP headers, and shell command operations.",
          "tasks": ["Protocol headers inspect", "Linux shell scripting", "Cryptographic tools"]
        },
        {
          "week": 2,
          "title": "Vulnerability Assessment & Focus Area",
          "description": "Identify systems flaws and audit configurations for focus area: $focus.",
          "tasks": ["Security scanning tools", "OWASP threat matrix", "Firewall rules analysis"]
        },
        {
          "week": 3,
          "title": "Exploitation & Defensive Mitigations",
          "description": "Implement detection controls and test defense mitigations.",
          "tasks": ["Exploit testing", "IDS/IPS config scripts", "Log correlation systems"]
        },
        {
          "week": 4,
          "title": "Security Compliance & Certification Plans",
          "description": "Review industry control frameworks and compile security sheets.",
          "tasks": ["ISO/IEC checklist audit", "Security log drafting", "Disaster recovery mocks"]
        }
      ];
    } else if (lower.contains('product') || lower.contains('manage') || lower.contains('scrum') || lower.contains('project')) {
      template = [
        {
          "week": 1,
          "title": "Strategy, Scope & Market Fit ($profession)",
          "description": "Define product canvases, evaluate competitors, and write core goal briefs.",
          "tasks": ["Goal brief blueprints", "Competitor matrix sheets", "KPI metrics maps"]
        },
        {
          "week": 2,
          "title": "User Story Mapping & Backlog Setup",
          "description": "Map user journeys and configure focus sprint lists: $focus.",
          "tasks": ["User journey mapping", "Sprint backlog items", "User story maps"]
        },
        {
          "week": 3,
          "title": "Metrics Tracking & A/B testing",
          "description": "Conduct tests, monitor funnel flows, and optimize conversion indices.",
          "tasks": ["A/B design setups", "Funnel analytics boards", "Telemetry metrics maps"]
        },
        {
          "week": 4,
          "title": "Stakeholder Reviews & Sprints Releases",
          "description": "Design roadmap presentations, conduct sprint reviews, and deploy product releases.",
          "tasks": ["Roadmap deck builds", "Sprint demo sessions", "User documentation sheets"]
        }
      ];
    } else {
      template = [
        {
          "week": 1,
          "title": "Foundational Concepts for $profession",
          "description": "Understand core principles, terminology, and foundational theories of the field.",
          "tasks": ["Core terminology basics", "Industry standards overview", "Basic tool setups"]
        },
        {
          "week": 2,
          "title": "Practical Execution ($focus)",
          "description": "Develop core skills with a primary focus on: $focus.",
          "tasks": ["Hands-on lab exercises", "Intermediate methodologies", "Honing basic techniques"]
        },
        {
          "week": 3,
          "title": "Real-World Projects & Case Studies",
          "description": "Analyze real scenarios and build projects to apply your skills.",
          "tasks": ["Guided project design", "Problem-solving analysis", "Case summary writing"]
        },
        {
          "week": 4,
          "title": "Advanced Integration & Strategy",
          "description": "Connect all learnings, understand advanced topics, and build a career roadmap.",
          "tasks": ["Portfolio showcase items", "Final skill assessment", "Career planning sheet"]
        }
      ];
    }

    final cloned = template.map((m) {
      return {
        'week': m['week'],
        'title': m['title'],
        'description': m['description'],
        'tasks': List<String>.from(m['tasks'] as Iterable),
      };
    }).toList();

    if (experience == 'Intermediate') {
      for (var m in cloned) {
        m['title'] = 'Intermediate ' + (m['title'] as String);
        m['tasks'] = (m['tasks'] as List<String>).map((t) => 'Advanced ' + t).toList();
      }
    } else if (experience == 'Advanced') {
      for (var m in cloned) {
        m['title'] = 'Architecting ' + (m['title'] as String);
        m['tasks'] = (m['tasks'] as List<String>).map((t) => t + ' (Optimization & Scale)').toList();
      }
    }

    if (studyTime == '1-2 hours/day') {
      for (var m in cloned) {
        m['description'] = (m['description'] as String) + ' (Slow-paced review over 2 weeks)';
      }
    } else if (studyTime == 'Full-time') {
      for (var m in cloned) {
        m['description'] = (m['description'] as String) + ' (Intensive deep dive)';
        (m['tasks'] as List<String>).add('Build portfolio project');
      }
    }

    return cloned;
  }

  // Generate structured GenUI JSON mocks to make app fully responsive instantly
  Future<void> _generateMockResponse(String query) async {
    // Simulate thinking delay
    await Future.delayed(const Duration(milliseconds: 1200));

    final lower = query.toLowerCase();
    String surfaceId = 's_${DateTime.now().millisecondsSinceEpoch}';
    String responseText = '';

    final roles = [
      'data analyst', 'data analytics', 'doctor', 'medical', 'physician', 
      'ca', 'cma', 'accounting', 'accountant', 'android', 'java', 
      'robotics', 'machine learning', 'ml', 'ai', 'web', 'frontend', 'backend', 'full stack', 'fullstack'
    ];

    final isSubmission = lower.contains('submitanswer');
    final isFreshRoadmap = lower.contains('roadmap') || 
                           lower.contains('become a') || 
                           lower.contains('path') ||
                           lower.contains('career') ||
                           roles.any((role) => lower.contains(role));

    if (isSubmission) {
      String questionId = 'q1';
      String selectedOption = '';
      
      try {
        final Map<String, dynamic> actionMap = jsonDecode(query);
        final action = actionMap['action'] as Map<String, dynamic>?;
        final context = action?['context'] as Map<String, dynamic>?;
        if (context != null) {
          questionId = context['questionId'] ?? 'q1';
          selectedOption = context['selectedOption'] ?? '';
        }
      } catch (_) {
        final idMatch = RegExp(r'"questionId"\s*:\s*"([^"]*)"').firstMatch(query);
        final optMatch = RegExp(r'"selectedOption"\s*:\s*"([^"]*)"').firstMatch(query);
        if (idMatch != null) questionId = idMatch.group(1)!;
        if (optMatch != null) selectedOption = optMatch.group(1)!;
      }

      final parts = questionId.split('|');
      final step = parts[0];
      final profession = parts.length > 1 ? parts[1] : 'Professional';

      if (step == 'q1') {
        final experience = selectedOption;
        responseText = 'Got it, you are at an $experience level. Let\'s specify your main focus area:';
        
        final nextId = 'q2|$profession|$experience';
        
        List<String> focusOptions = ["Core Fundamentals", "Architecture & Scales", "Project Building"];
        final lowerProf = profession.toLowerCase();
        if (lowerProf.contains('flutter') || lowerProf.contains('android') || lowerProf.contains('java')) {
          focusOptions = ["App Architecture", "State Management (Riverpod/etc)", "UI/Animations"];
        } else if (lowerProf.contains('data') || lowerProf.contains('ml') || lowerProf.contains('ai')) {
          focusOptions = ["Data Pipeline/SQL", "Model Training & Tuning", "MLOps/Cloud deployment"];
        } else if (lowerProf.contains('firebase')) {
          focusOptions = ["Auth & Database Realtime", "Cloud Functions & Security Rules", "Analytics & Growth"];
        } else if (lowerProf.contains('web')) {
          focusOptions = ["Frontend (React/HTML/CSS)", "Backend (Node/SQL)", "Fullstack Systems"];
        } else if (lowerProf.contains('design') || lowerProf.contains('ui') || lowerProf.contains('ux')) {
          focusOptions = ["Wireframing & Prototyping", "Design Systems & Figma", "User Research & Testing"];
        } else if (lowerProf.contains('security') || lowerProf.contains('cyber')) {
          focusOptions = ["Penetration Testing", "Network Defense & Firewalls", "Security Compliance & Auditing"];
        } else if (lowerProf.contains('product') || lowerProf.contains('manage')) {
          focusOptions = ["Product Roadmap Strategy", "Backlog & Story Mapping", "Funnel Metrics & Analytics"];
        }

        final optionsJson = focusOptions.map((o) => '"$o"').join(', ');

        final json = '''
        {
          "version": "v0.9",
          "createSurface": {
            "surfaceId": "$surfaceId",
            "catalogId": "careerPilotCatalog"
          }
        }
        {
          "version": "v0.9",
          "updateComponents": {
            "surfaceId": "$surfaceId",
            "components": [
              {
                "id": "root",
                "component": "CareerQuestion",
                "questionId": "$nextId",
                "question": "What is your primary focus area for becoming a $profession?",
                "options": [$optionsJson]
              }
            ]
          }
        }
        ''';

        _adapter.addChunk(json.trim());
        return;
      } else if (step == 'q2') {
        final experience = parts.length > 2 ? parts[2] : 'Beginner';
        final focus = selectedOption;
        responseText = 'Excellent. Focusing on $focus is a great path. Lastly, how much time can you commit daily?';
        
        final nextId = 'q3|$profession|$experience|$focus';

        final json = '''
        {
          "version": "v0.9",
          "createSurface": {
            "surfaceId": "$surfaceId",
            "catalogId": "careerPilotCatalog"
          }
        }
        {
          "version": "v0.9",
          "updateComponents": {
            "surfaceId": "$surfaceId",
            "components": [
              {
                "id": "root",
                "component": "CareerQuestion",
                "questionId": "$nextId",
                "question": "How much daily study time can you commit?",
                "options": ["1-2 hours/day", "3-5 hours/day", "Full-time"]
              }
            ]
          }
        }
        ''';

        _adapter.addChunk(json.trim());
        return;
      } else if (step == 'q3') {
        final experience = parts.length > 2 ? parts[2] : 'Beginner';
        final focus = parts.length > 3 ? parts[3] : 'Core Fundamentals';
        final studyTime = selectedOption;

        responseText = 'All set! Here is your personalized learning path for $profession, designed for an $experience level focusing on $focus ($studyTime):';
        
        final customized = _getDynamicMockMilestones(profession, experience, focus, studyTime);

        final milestonesJson = customized.map((m) => '''
            {
              "week": ${m['week']},
              "title": "${m['title']}",
              "description": "${m['description']}",
              "tasks": ${jsonEncode(m['tasks'])}
            }''').join(',\n');

        final json = '''
        {
          "version": "v0.9",
          "createSurface": {
            "surfaceId": "$surfaceId",
            "catalogId": "careerPilotCatalog"
          }
        }
        {
          "version": "v0.9",
          "updateComponents": {
            "surfaceId": "$surfaceId",
            "components": [
              {
                "id": "root",
                "component": "TimelineItem",
                "title": "$profession Path",
                "milestones": [
  $milestonesJson
                ]
              }
            ]
          }
        }
        ''';

        _adapter.addChunk(json.trim());
        return;
      }
    }

    if (isFreshRoadmap && !isSubmission) {
      String profession = _extractRoleName(query);
      responseText = 'To design the perfect customized learning roadmap for becoming a $profession, please answer a few quick questions about your background:';
      
      final nextId = 'q1|$profession';

      final json = '''
      {
        "version": "v0.9",
        "createSurface": {
          "surfaceId": "$surfaceId",
          "catalogId": "careerPilotCatalog"
        }
      }
      {
        "version": "v0.9",
        "updateComponents": {
          "surfaceId": "$surfaceId",
          "components": [
            {
              "id": "root",
              "component": "CareerQuestion",
              "questionId": "$nextId",
              "question": "What is your current experience level in $profession?",
              "options": ["Beginner", "Intermediate", "Advanced"]
            }
          ]
        }
      }
      ''';

      _adapter.addChunk(json.trim());
      return;
    }

    if (lower.contains('gap') || lower.contains('compare') || lower.contains('skills')) {
      responseText = 'I have evaluated your skills relative to your career goals:';
      final json = '''
      {
        "version": "v0.9",
        "createSurface": {
          "surfaceId": "$surfaceId",
          "catalogId": "careerPilotCatalog"
        }
      }
      {
        "version": "v0.9",
        "updateComponents": {
          "surfaceId": "$surfaceId",
          "components": [
            {
              "id": "root",
              "component": "SkillCompare",
              "currentPath": "Junior Developer",
              "targetPath": "Flutter Architect",
              "matchPercentage": 65,
              "overlappingSkills": ["HTML", "CSS", "Javascript", "Basic OOP"],
              "missingSkills": ["Clean Architecture", "Riverpod", "Dynamic GenUI", "App Performance Tuning"]
            }
          ]
        }
      }
      ''';
      _adapter.addChunk(json.trim());
    } 
    else if (lower.contains('project') || lower.contains('recommend')) {
      responseText = 'Here are 3 projects ranging from beginner to advanced to help you practice:';
      final json = '''
      {
        "version": "v0.9",
        "createSurface": {
          "surfaceId": "$surfaceId",
          "catalogId": "careerPilotCatalog"
        }
      }
      {
        "version": "v0.9",
        "updateComponents": {
          "surfaceId": "$surfaceId",
          "components": [
            {
              "id": "root",
              "component": "ProjectSuggestions",
              "projects": [
                {
                  "title": "Modern Recipe Book",
                  "difficulty": "Beginner",
                  "description": "A responsive app displaying recipes with search filters, offline caching using Hive, and detail animations.",
                  "techStack": ["Flutter", "Hive", "Google Fonts"],
                  "githubIdeas": ["Set up core folder structures", "Design a custom GridView", "Store bookmarks locally"]
                },
                {
                  "title": "CareerPilot Roadmap Helper",
                  "difficulty": "Intermediate",
                  "description": "A career progress tracker rendering milestone progress and storing checklist states in localized boxes.",
                  "techStack": ["Flutter", "Riverpod", "percent_indicator"],
                  "githubIdeas": ["Define models and repositories", "Inject Riverpod listeners", "Animate daily goal rings"]
                },
                {
                  "title": "Sage Generative UI Client",
                  "difficulty": "Advanced",
                  "description": "An AI assistant client that streams Gemini text chunks and dynamically resolves widgets using GenUI.",
                  "techStack": ["Flutter", "Google Generative AI", "genui", "json_schema_builder"],
                  "githubIdeas": ["Establish A2uiTransportAdapter", "Map custom CatalogItem parameters", "Configure structured JSON schemas"]
                }
              ]
            }
          ]
        }
      }
      ''';
      _adapter.addChunk(json.trim());
    }
    else if (lower.contains('resume') || lower.contains('ats')) {
      responseText = 'Here is your resume ATS and quality scoring report:';
      final json = '''
      {
        "version": "v0.9",
        "createSurface": {
          "surfaceId": "$surfaceId",
          "catalogId": "careerPilotCatalog"
        }
      }
      {
        "version": "v0.9",
        "updateComponents": {
          "surfaceId": "$surfaceId",
          "components": [
            {
              "id": "root",
              "component": "ResumeAnalysisReport",
              "atsScore": 82,
              "overallScore": 85,
              "missingKeywords": ["Clean Architecture", "CI/CD", "State Management", "Widget Tests"],
              "suggestions": [
                "Quantify your metrics: instead of 'built flutter apps', say 'boosted app load speed by 24% and user retention by 15%'.",
                "Place your core skills (Dart, Riverpod, GoRouter, Firebase) in a dedicated technical section at the top.",
                "Remove graphics and tables to ensure the ATS parser reads your contact details correctly."
              ]
            }
          ]
        }
      }
      ''';
      _adapter.addChunk(json.trim());
    }
    else if (lower.contains('interview') || lower.contains('practice') || lower.contains('question')) {
      responseText = 'I have prepared some interview practice tasks and questions for you:';
      final json = '''
      {
        "version": "v0.9",
        "createSurface": {
          "surfaceId": "$surfaceId",
          "catalogId": "careerPilotCatalog"
        }
      }
      {
        "version": "v0.9",
        "updateComponents": {
          "surfaceId": "$surfaceId",
          "components": [
            {
              "id": "root",
              "component": "InterviewQuestions",
              "questions": [
                {
                  "id": "q1",
                  "type": "Technical",
                  "question": "What is the difference between Hot Reload and Hot Restart in Flutter, and how do they impact state?",
                  "suggestedAnswer": "Hot Reload injects updated code source files into the running Dart VM, rebuilding the widget tree while preserving state. Hot Restart resets the app state back to its default values and compiles the code fresh, which is necessary when modifying main.dart, global initializations, or assets."
                },
                {
                  "id": "q2",
                  "type": "Technical",
                  "question": "Explain the Repository Pattern and why it is useful in Clean Architecture.",
                  "suggestedAnswer": "The Repository Pattern abstracts data sources (network vs local cache) from domain entities, providing a clean API interface. This decouples the business logic from underlying storage structures and allows developers to swap datasources easily during tests."
                },
                {
                  "id": "q3",
                  "type": "HR",
                  "question": "Describe a scenario where you faced a significant challenge in a software project and how you solved it.",
                  "suggestedAnswer": "Focus on the STAR method (Situation, Task, Action, Result). State the conflict clearly, describe what you did to analyze and solve it, and highlight positive project metrics (e.g. improved app responsiveness, successfully hit milestones, resolved dev-ops blocks)."
                }
              ]
            }
          ]
        }
      }
      ''';
      _adapter.addChunk(json.trim());
    }
    else {
      final isGreeting = lower.contains('hello') || lower.contains('hi') || lower.contains('hey') || lower == 'yo';
      if (isGreeting) {
        responseText = "Hi! I am your CareerPilot AI mentor. Ask me to: 'Generate a Roadmap for [Role]', 'Compare my skills', 'Analyze my resume', 'Suggest projects', or 'Give me interview practice'.";
        _adapter.addChunk(responseText);
      } else {
        // Fallback generic dynamic question Q1
        String profession = _extractRoleName(query);
        responseText = 'To design the perfect customized learning roadmap for becoming a $profession, please answer a few quick questions about your background:';
        
        final nextId = 'q1|$profession';

        final json = '''
        {
          "version": "v0.9",
          "createSurface": {
            "surfaceId": "$surfaceId",
            "catalogId": "careerPilotCatalog"
          }
        }
        {
          "version": "v0.9",
          "updateComponents": {
            "surfaceId": "$surfaceId",
            "components": [
              {
                "id": "root",
                "component": "CareerQuestion",
                "questionId": "$nextId",
                "question": "What is your current experience level in $profession?",
                "options": ["Beginner", "Intermediate", "Advanced"]
              }
            ]
          }
        }
        ''';

        _adapter.addChunk(json.trim());
      }
    }
  }

  List<Map<String, dynamic>> _cloneMilestones(List<Map<String, dynamic>> original) {
    return original.map((m) => {
      'week': m['week'],
      'title': m['title'],
      'description': m['description'],
      'tasks': List<String>.from(m['tasks'] as Iterable),
    }).toList();
  }

  List<Map<String, dynamic>> _adjustMilestones(
    List<Map<String, dynamic>> baseMilestones, 
    String experience, 
    String studyTime
  ) {
    // 1. Adjust based on experience
    if (experience == 'Intermediate') {
      for (var m in baseMilestones) {
        m['title'] = 'Intermediate ' + m['title'];
        m['tasks'] = (m['tasks'] as List<String>).map((t) => 'Advanced ' + t).toList();
      }
    } else if (experience == 'Advanced') {
      for (var m in baseMilestones) {
        m['title'] = 'Architecting ' + m['title'];
        m['tasks'] = (m['tasks'] as List<String>).map((t) => t + ' (Optimization & Scale)').toList();
      }
    }

    // 2. Adjust based on studyTime
    if (studyTime == '1-2 hours/day') {
      for (var m in baseMilestones) {
        m['description'] = m['description'] + ' (Slow-paced review over 2 weeks)';
      }
    } else if (studyTime == 'Full-time') {
      for (var m in baseMilestones) {
        m['description'] = m['description'] + ' (Intensive deep dive)';
        (m['tasks'] as List<String>).add('Build portfolio project');
      }
    }

    return baseMilestones;
  }

  List<Map<String, dynamic>> _getFlutterMilestones() {
    return [
      {
        "week": 1,
        "title": "Dart Fundamentals",
        "description": "Understand core Dart programming concepts: variables, operators, control structures, and collections.",
        "tasks": ["Variables", "Functions", "OOP Principles"]
      },
      {
        "week": 2,
        "title": "Flutter Basics & Widgets",
        "description": "Build your first Flutter app. Master stateless and stateful widgets, lists, and layout alignments.",
        "tasks": ["Material 3 Design", "Scaffold", "ListView", "Stateful widgets"]
      },
      {
        "week": 3,
        "title": "State Management (Riverpod)",
        "description": "Learn clean state management using Riverpod. Manage local data models, future providers, and notifier scopes.",
        "tasks": ["Providers", "NotifierProvider", "FutureProvider"]
      },
      {
        "week": 4,
        "title": "APIs & Databases",
        "description": "Integrate REST APIs with Dio, parse structured JSON, and cache configurations locally using Hive.",
        "tasks": ["Dio integration", "JSON serialization", "Hive database"]
      }
    ];
  }

  List<Map<String, dynamic>> _getDataAnalystMilestones() {
    return [
      {
        "week": 1,
        "title": "Excel & Statistical Basics",
        "description": "Learn formulas, pivot tables, data cleaning, and fundamental descriptive statistics.",
        "tasks": ["Pivot Tables", "VLOOKUP & XLOOKUP", "Descriptive Stats"]
      },
      {
        "week": 2,
        "title": "SQL Data Extraction",
        "description": "Master relational database queries, joins, aggregations, and subqueries.",
        "tasks": ["SELECT Queries", "JOIN operations", "GROUP BY & HAVING"]
      },
      {
        "week": 3,
        "title": "Data Visualization (Tableau/PowerBI)",
        "description": "Connect to data sources, design interactive dashboards, and build storyboards.",
        "tasks": ["Dashboard Design", "Calculated Fields", "Publishing Reports"]
      },
      {
        "week": 4,
        "title": "Python for Data Analysis",
        "description": "Get started with Python, Jupyter Notebooks, Pandas, and NumPy for data manipulation.",
        "tasks": ["Pandas DataFrames", "Data Cleaning in Python", "Matplotlib charts"]
      }
    ];
  }

  List<Map<String, dynamic>> _getDoctorMilestones() {
    return [
      {
        "week": 1,
        "title": "Pre-Med & Science Basics",
        "description": "Focus on organic chemistry, biochemistry, biology, and MCAT preparation foundations.",
        "tasks": ["Biology Review", "Chemistry Lab", "MCAT Syllabus"]
      },
      {
        "week": 2,
        "title": "Medical School Foundations",
        "description": "Begin study of human anatomy, physiology, pharmacology, and core organ systems.",
        "tasks": ["Skeletal System", "Cardiovascular system", "Pharmacology basics"]
      },
      {
        "week": 3,
        "title": "Clinical Rotations & Pathology",
        "description": "Observe patient care in internal medicine, pediatrics, surgery, and learn general pathology.",
        "tasks": ["Clinical history taking", "Surgical shadowing", "Pathology review"]
      },
      {
        "week": 4,
        "title": "Residency Match & Licensing",
        "description": "Prepare for licensing exams (e.g. USMLE), complete final rotations, and apply for matching.",
        "tasks": ["USMLE Prep", "Residency Application", "Clinical practice mock"]
      }
    ];
  }

  List<Map<String, dynamic>> _getAccountingMilestones() {
    return [
      {
        "week": 1,
        "title": "Accounting Principles & Foundations",
        "description": "Learn double-entry bookkeeping, ledger accounts, trial balances, and financial statement structures.",
        "tasks": ["Journal Entries", "Ledger Accounts", "Balance Sheet basics"]
      },
      {
        "week": 2,
        "title": "Corporate & Cost Accounting",
        "description": "Master cost allocation, budgeting, overhead analysis, and financial reporting standards.",
        "tasks": ["Standard Costing", "Variance Analysis", "IFRS/GAAP standards"]
      },
      {
        "week": 3,
        "title": "Taxation & Audit Systems",
        "description": "Study direct/indirect tax laws, auditing procedures, internal controls, and verification practices.",
        "tasks": ["Income Tax planning", "Vouching & Verification", "Audit reports"]
      },
      {
        "week": 4,
        "title": "Financial Management & Advisory",
        "description": "Explore capital budgeting, portfolio management, treasury operations, and strategic financial decision making.",
        "tasks": ["Capital Budgeting", "Working Capital management", "Strategic planning"]
      }
    ];
  }

  List<Map<String, dynamic>> _getAndroidMilestones() {
    return [
      {
        "week": 1,
        "title": "Kotlin Fundamentals",
        "description": "Master Kotlin syntax, null safety, collections, and functional constructs.",
        "tasks": ["Variables & Null Safety", "Control Flow & OOP", "Coroutines basics"]
      },
      {
        "week": 2,
        "title": "Android Core & Jetpack Compose",
        "description": "Build responsive interfaces using Jetpack Compose, state handlers, and lifecycle observers.",
        "tasks": ["Compose Layouts", "State Management", "Activity Lifecycle"]
      },
      {
        "week": 3,
        "title": "Architecture & DI",
        "description": "Implement Clean Architecture with MVVM, fetch data with Retrofit, and set up Hilt.",
        "tasks": ["Retrofit APIs", "Hilt Injection", "MVVM & Repository Pattern"]
      },
      {
        "week": 4,
        "title": "Local Storage & Testing",
        "description": "Integrate Room DB for offline caching, write unit tests and Compose UI tests.",
        "tasks": ["Room Database", "JUnit & Mockk tests", "UI testing in Compose"]
      }
    ];
  }

  List<Map<String, dynamic>> _getJavaMilestones() {
    return [
      {
        "week": 1,
        "title": "Java Core & OOP",
        "description": "Deep dive into Java syntax, Collections framework, Generics, and OOP design.",
        "tasks": ["OOP Principles", "Java Collections", "Exception Handling"]
      },
      {
        "week": 2,
        "title": "Concurrency & Database Connection",
        "description": "Understand Java multithreading, ExecutorService, and JDBC database access.",
        "tasks": ["Multithreading", "JDBC & SQL Connectivity", "Java Stream API"]
      },
      {
        "week": 3,
        "title": "Spring Boot & REST Services",
        "description": "Build backend REST APIs with Spring Boot web modules and Spring Data JPA.",
        "tasks": ["Spring Boot Setup", "REST Controllers", "Spring Data JPA"]
      },
      {
        "week": 4,
        "title": "Microservices & Containers",
        "description": "Learn Spring Cloud config, dockerize Java apps, and write JUnit integration tests.",
        "tasks": ["Microservices Basics", "Dockerization", "JUnit & Mockito"]
      }
    ];
  }

  List<Map<String, dynamic>> _getRoboticsMilestones() {
    return [
      {
        "week": 1,
        "title": "Introduction to ROS & Linux",
        "description": "Set up Ubuntu Linux, understand ROS2 architecture, nodes, topics, and run basic simulations.",
        "tasks": ["ROS2 Installation", "Nodes & Topics", "CLI & Launch Files"]
      },
      {
        "week": 2,
        "title": "Sensors, Actuators & Microcontrollers",
        "description": "Interface with sensors (LIDAR, IMU) and actuators using microcontrollers to read physical data.",
        "tasks": ["GPIO Programming", "Sensor Interfacing", "Serial Data Protocols"]
      },
      {
        "week": 3,
        "title": "Kinematics & Simulation",
        "description": "Master kinematics, PID control loops, and simulate robot dynamics inside Gazebo.",
        "tasks": ["Gazebo Simulation", "PID Tuning", "URDF Robot Modeling"]
      },
      {
        "week": 4,
        "title": "Navigation & Path Planning",
        "description": "Implement SLAM, configure the Nav2 stack, and achieve autonomous mobile robot navigation.",
        "tasks": ["SLAM Mapping", "Nav2 Stack Config", "Autonomous Path Finding"]
      }
    ];
  }

  List<Map<String, dynamic>> _getMachineLearningMilestones() {
    return [
      {
        "week": 1,
        "title": "Python & Math Foundations",
        "description": "Master Pandas, NumPy, linear algebra, multivariable calculus, and probability.",
        "tasks": ["Pandas & NumPy", "Linear Algebra", "Probability Basics"]
      },
      {
        "week": 2,
        "title": "Classical Machine Learning",
        "description": "Implement regression, classification, clustering, and evaluate models using Scikit-Learn.",
        "tasks": ["Supervised Models", "Unsupervised Clustering", "Model Evaluation"]
      },
      {
        "week": 3,
        "title": "Deep Learning & Neural Networks",
        "description": "Build multi-layer perceptrons and CNNs from scratch and train them using PyTorch/TensorFlow.",
        "tasks": ["Neural Nets from Scratch", "PyTorch Framework", "CNN Image Models"]
      },
      {
        "week": 4,
        "title": "NLP & LLM Architectures",
        "description": "Understand transformers, tokenize inputs, fine-tune model parameters, and construct RAG pipelines.",
        "tasks": ["HuggingFace Transformers", "Fine-Tuning LLMs", "RAG Pipeline Build"]
      }
    ];
  }

  List<Map<String, dynamic>> _getWebMilestones() {
    return [
      {
        "week": 1,
        "title": "HTML, CSS & JavaScript Essentials",
        "description": "Master modern HTML5 semantic markup, CSS layouts (Flexbox/Grid), and ES6+ asynchronous JavaScript.",
        "tasks": ["Asynchronous JS", "DOM Manipulation", "Responsive Web Design"]
      },
      {
        "week": 2,
        "title": "React & Frontend Architecture",
        "description": "Build functional component structures using React, manage local hooks, routing, and consume APIs.",
        "tasks": ["React Hooks", "State Management", "Routing & API Fetch"]
      },
      {
        "week": 3,
        "title": "Backend APIs & Databases",
        "description": "Establish Express web servers with Node.js, create REST endpoints, and connect SQL/NoSQL databases.",
        "tasks": ["REST API Routing", "MongoDB / PostgreSQL", "JWT Security Checks"]
      },
      {
        "week": 4,
        "title": "DevOps, Containerization & CI/CD",
        "description": "Implement Git workflow branches, containerize environments with Docker, and deploy live on cloud hosts.",
        "tasks": ["Git Branching Flow", "Dockerizing Apps", "Hosting & CD Pipelines"]
      }
    ];
  }

  List<Map<String, dynamic>> _getGenericMilestones(String profession) {
    return [
      {
        "week": 1,
        "title": "Foundational Concepts",
        "description": "Understand core principles, terminology, and foundational theories of the $profession field.",
        "tasks": ["Core Terminology", "Industry Overview", "Basic Frameworks"]
      },
      {
        "week": 2,
        "title": "Essential Tools & Methods",
        "description": "Get hands-on practice with the industry-standard software, techniques, and methodologies.",
        "tasks": ["Software Setup", "Hands-on Exercises", "Best Practices"]
      },
      {
        "week": 3,
        "title": "Intermediate Projects & Case Studies",
        "description": "Analyze real-world scenarios, complete guided projects, and develop problem-solving strategies.",
        "tasks": ["Case Analysis", "Guided Practice", "Troubleshooting"]
      },
      {
        "week": 4,
        "title": "Advanced Integration & Strategy",
        "description": "Connect all learnings, understand advanced topics, and build a portfolio to showcase your expertise.",
        "tasks": ["Portfolio Project", "Final Assessment", "Career Guidance"]
      }
    ];
  }

  String _extractRoleName(String query) {
    String role = query
        .replaceAll(RegExp(r'\b(become|a|an|how|to|roadmap|path|career|guide|for|details|give|me|show|create)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (role.isEmpty) {
      role = 'Professional';
    }
    // Capitalize words
    return role.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void dispose() => _adapter.dispose();
}
