import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:careerpilot_ai/core/theme/app_theme.dart';

// --- CUSTOM CATALOG ITEMS FOR CAREERPILOT AI ---

/// 1. Timeline Component: Displays a step-by-step career timeline
final CatalogItem timelineItem = CatalogItem(
  name: 'TimelineItem',
  dataSchema: S.object(
    description: 'A timeline widget displaying career roadmap weeks or milestones.',
    properties: {
      'title': S.string(description: 'Title of the roadmap'),
      'milestones': S.list(
        items: S.object(
          properties: {
            'week': S.integer(description: 'Week number'),
            'title': S.string(description: 'Milestone title'),
            'description': S.string(description: 'Description of what will be learned'),
            'tasks': S.list(items: S.string(), description: 'Key skills or tasks to complete'),
          },
          required: ['week', 'title', 'description'],
        ),
      ),
    },
    required: ['title', 'milestones'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Career Path';
    final milestones = data['milestones'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map_outlined, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: milestones.length,
              itemBuilder: (context, idx) {
                final milestone = milestones[idx] as Map<String, dynamic>;
                final week = milestone['week'] ?? (idx + 1);
                final mTitle = milestone['title'] ?? '';
                final mDesc = milestone['description'] ?? '';
                final tasks = milestone['tasks'] as List<dynamic>? ?? [];
                final theme = Theme.of(context);

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'W$week',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: theme.colorScheme.primary.withOpacity(0.15),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mDesc,
                                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                              ),
                              if (tasks.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: tasks.map((t) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.onSurface.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                                      ),
                                      child: Text(
                                        t.toString(),
                                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'saveGeneratedRoadmap',
                      sourceComponentId: itemContext.id,
                      context: data,
                    ),
                  );
                  ScaffoldMessenger.of(itemContext.buildContext).showSnackBar(
                    const SnackBar(content: Text('Roadmap saved to Dashboard!')),
                  );
                },
                child: const Text('Add Roadmap to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

/// 2. Checklist Component: Renders learning checklist/tasks
final CatalogItem skillChecklistItem = CatalogItem(
  name: 'SkillChecklist',
  dataSchema: S.object(
    description: 'A list of skill checkpoints with checklist bubbles.',
    properties: {
      'title': S.string(description: 'List title'),
      'items': S.list(
        items: S.object(
          properties: {
            'id': S.string(description: 'Task unique identifier'),
            'label': S.string(description: 'Task content'),
            'completed': S.boolean(description: 'Initial completed state'),
          },
          required: ['id', 'label'],
        ),
      ),
    },
    required: ['items'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Milestone Checklist';
    final items = data['items'] as List<dynamic>? ?? [];

    return StatefulBuilder(
      builder: (context, setState) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...items.map((item) {
                  final map = item as Map<String, dynamic>;
                  final id = map['id'] ?? '';
                  final label = map['label'] ?? '';
                  final completed = map['completed'] ?? false;

                  return CheckboxListTile(
                    title: Text(label, style: const TextStyle(fontSize: 14)),
                    value: completed,
                    activeColor: AppTheme.primaryColor,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        map['completed'] = val;
                      });
                      itemContext.dispatchEvent(
                        UserActionEvent(
                          name: 'checkTaskState',
                          sourceComponentId: itemContext.id,
                          context: {'id': id, 'label': label, 'completed': val},
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  },
);

/// 3. Skill Compare Component: Visualizes skill gap analysis
final CatalogItem skillCompareItem = CatalogItem(
  name: 'SkillCompare',
  dataSchema: S.object(
    description: 'A side-by-side current skills vs target skills gap report.',
    properties: {
      'currentPath': S.string(),
      'targetPath': S.string(),
      'matchPercentage': S.integer(description: 'Match percentage score (0-100)'),
      'overlappingSkills': S.list(items: S.string()),
      'missingSkills': S.list(items: S.string()),
    },
    required: ['targetPath', 'matchPercentage', 'missingSkills'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, dynamic>;
    final currentPath = data['currentPath'] as String? ?? 'Current Profile';
    final targetPath = data['targetPath'] as String? ?? 'Target Profile';
    final match = data['matchPercentage'] as int? ?? 50;
    final overlap = data['overlappingSkills'] as List<dynamic>? ?? [];
    final missing = data['missingSkills'] as List<dynamic>? ?? [];

    final theme = Theme.of(itemContext.buildContext);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Skill Gap Analysis',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$currentPath ➜ $targetPath',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                CircularPercentIndicator(
                  radius: 30.0,
                  lineWidth: 6.0,
                  percent: match / 100,
                  center: Text('$match%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  progressColor: AppTheme.accentColor,
                  backgroundColor: AppTheme.accentColor.withOpacity(0.2),
                  circularStrokeCap: CircularStrokeCap.round,
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (overlap.isNotEmpty) ...[
              const Text('Matching Skills', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: overlap.map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.12)),
                    ),
                    child: Text(
                      s.toString(),
                      style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            const Text('Missing Skills (Gap)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: missing.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.12)),
                  ),
                  child: Text(
                    s.toString(),
                    style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'generateRoadmapForGap',
                      sourceComponentId: itemContext.id,
                      context: {'target': targetPath, 'missing': missing},
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate Roadmap to Bridge Gap'),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

/// 4. Project Suggestions Component: Generates starter, intermediate, and advanced tasks
final CatalogItem projectSuggestionsItem = CatalogItem(
  name: 'ProjectSuggestions',
  dataSchema: S.object(
    description: 'A list of recommended projects.',
    properties: {
      'projects': S.list(
        items: S.object(
          properties: {
            'title': S.string(),
            'difficulty': S.string(description: 'Beginner, Intermediate, or Advanced'),
            'description': S.string(),
            'techStack': S.list(items: S.string()),
            'githubIdeas': S.list(items: S.string(), description: 'Key components to structure in GitHub repo'),
          },
          required: ['title', 'difficulty', 'description', 'techStack'],
        ),
      ),
    },
    required: ['projects'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, dynamic>;
    final projects = data['projects'] as List<dynamic>? ?? [];

    return Column(
      children: projects.map((proj) {
        final map = proj as Map<String, dynamic>;
        final title = map['title'] as String? ?? '';
        final diff = map['difficulty'] as String? ?? 'Intermediate';
        final desc = map['description'] as String? ?? '';
        final stack = map['techStack'] as List<dynamic>? ?? [];
        final github = map['githubIdeas'] as List<dynamic>? ?? [];

        final diffColor = diff.toLowerCase() == 'beginner' 
            ? Colors.green 
            : diff.toLowerCase() == 'advanced' 
                ? Colors.red 
                : Colors.orange;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: diffColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        diff,
                        style: TextStyle(fontSize: 11, color: diffColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: TextStyle(fontSize: 13, height: 1.4, color: Theme.of(itemContext.buildContext).colorScheme.onSurface.withOpacity(0.85)),
                ),
                const SizedBox(height: 12),
                
                // Tech Stack
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: stack.map((s) {
                    final theme = Theme.of(itemContext.buildContext);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                      ),
                      child: Text(
                        s.toString(),
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                      ),
                    );
                  }).toList(),
                ),
                
                if (github.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Key GitHub Modules:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  ...github.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check, size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(g.toString(), style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  )),
                ],
                
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      itemContext.dispatchEvent(
                        UserActionEvent(
                          name: 'generateProjectSetupGuideline',
                          sourceComponentId: itemContext.id,
                          context: {'project': title, 'difficulty': diff},
                        ),
                      );
                    },
                    child: const Text('Request Initial Project File Structure'),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  },
);

/// 5. Resume Analysis Report Component
final CatalogItem resumeAnalysisItem = CatalogItem(
  name: 'ResumeAnalysisReport',
  dataSchema: S.object(
    description: 'An ATS resume feedback report.',
    properties: {
      'atsScore': S.integer(description: 'ATS optimization score (0-100)'),
      'overallScore': S.integer(description: 'General resume score (0-100)'),
      'missingKeywords': S.list(items: S.string()),
      'suggestions': S.list(items: S.string()),
    },
    required: ['atsScore', 'overallScore', 'suggestions'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, dynamic>;
    final ats = data['atsScore'] as int? ?? 60;
    final overall = data['overallScore'] as int? ?? 70;
    final keywords = data['missingKeywords'] as List<dynamic>? ?? [];
    final suggestions = data['suggestions'] as List<dynamic>? ?? [];

    final theme = Theme.of(itemContext.buildContext);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resume Scan Feedback',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                CircularPercentIndicator(
                  radius: 36.0,
                  lineWidth: 8.0,
                  percent: ats / 100,
                  center: Text('$ats%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  progressColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                  header: const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('ATS Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  circularStrokeCap: CircularStrokeCap.round,
                ),
                CircularPercentIndicator(
                  radius: 36.0,
                  lineWidth: 8.0,
                  percent: overall / 100,
                  center: Text('$overall%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  progressColor: AppTheme.secondaryColor,
                  backgroundColor: AppTheme.secondaryColor.withOpacity(0.2),
                  header: const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('Overall Quality', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  circularStrokeCap: CircularStrokeCap.round,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (keywords.isNotEmpty) ...[
              const Text('Missing Keywords to Add:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: keywords.map((k) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                    ),
                    child: Text(
                      k.toString(),
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            const Text('Actionable Suggestions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ...suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.toString(),
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  },
);

/// 6. Interview Practice Component: Interactive practice questions
final CatalogItem interviewQuestionsItem = CatalogItem(
  name: 'InterviewQuestions',
  dataSchema: S.object(
    description: 'A list of mock interview questions.',
    properties: {
      'questions': S.list(
        items: S.object(
          properties: {
            'id': S.string(),
            'type': S.string(description: 'Technical or HR'),
            'question': S.string(),
            'suggestedAnswer': S.string(),
          },
          required: ['id', 'type', 'question', 'suggestedAnswer'],
        ),
      ),
    },
    required: ['questions'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, dynamic>;
    final questions = data['questions'] as List<dynamic>? ?? [];

    return Column(
      children: questions.map((q) {
        final map = q as Map<String, dynamic>;
        final id = map['id'] ?? '';
        final qType = map['type'] ?? 'Technical';
        final questionText = map['question'] ?? '';
        final suggestedAnswer = map['suggestedAnswer'] ?? '';

        return StatefulBuilder(
          builder: (context, setState) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: qType.toLowerCase() == 'hr' ? Colors.blue.withOpacity(0.1) : Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        qType,
                        style: TextStyle(
                          fontSize: 10,
                          color: qType.toLowerCase() == 'hr' ? Colors.blue : Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Interview practice task', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  child: Text(
                    questionText,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Suggested Answer:',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          suggestedAnswer,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              itemContext.dispatchEvent(
                                UserActionEvent(
                                  name: 'requestPracticeFeedback',
                                  sourceComponentId: itemContext.id,
                                  context: {'questionId': id, 'question': questionText},
                                ),
                              );
                            },
                            icon: const Icon(Icons.mic_none, size: 18),
                            label: const Text('Simulate Answer Input & Rate Me'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }).toList(),
    );
  },
);

// --- 7. Career Questionnaire Component ---
final CatalogItem careerQuestionnaire = CatalogItem(
  name: 'CareerQuestionnaire',
  dataSchema: S.object(
    description: 'A questionnaire component asking the user for profile details to customize their career path.',
    properties: {
      'profession': S.string(description: 'The targeted career profession (e.g. Flutter Developer, Product Manager)'),
    },
    required: ['profession'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, dynamic>;
    final profession = data['profession'] as String? ?? 'Professional';
    return _CareerQuestionnaireWidget(
      itemContext: itemContext,
      profession: profession,
    );
  },
);

class _CareerQuestionnaireWidget extends StatefulWidget {
  final CatalogItemContext itemContext;
  final String profession;

  const _CareerQuestionnaireWidget({
    required this.itemContext,
    required this.profession,
  });

  @override
  State<_CareerQuestionnaireWidget> createState() => _CareerQuestionnaireWidgetState();
}

class _CareerQuestionnaireWidgetState extends State<_CareerQuestionnaireWidget> {
  String _selectedStatus = 'Student';
  String _selectedExperience = 'Beginner';
  String _selectedTime = '1-2 hours/day';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_outlined, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Customize Your ${widget.profession} Path',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 1. Current Status
            const Text(
              'What is your current status?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Student', 'Graduate', 'Working Professional'].map((status) {
                final isSelected = _selectedStatus == status;
                return ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : theme.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedStatus = status);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 2. Experience Level
            const Text(
              'What is your experience level in this field?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Beginner', 'Intermediate', 'Advanced'].map((level) {
                final isSelected = _selectedExperience == level;
                return ChoiceChip(
                  label: Text(level),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : theme.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedExperience = level);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 3. Daily Study Time
            const Text(
              'How much time can you spend studying daily?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['1-2 hours/day', '3-5 hours/day', 'Full-time'].map((time) {
                final isSelected = _selectedTime == time;
                return ChoiceChip(
                  label: Text(time),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : theme.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedTime = time);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  widget.itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'submitQuestionnaire',
                      sourceComponentId: widget.itemContext.id,
                      context: {
                        'profession': widget.profession,
                        'status': _selectedStatus,
                        'experience': _selectedExperience,
                        'studyTime': _selectedTime,
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Submit & Design my Roadmap'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 8. Dynamic Career Question Component ---
final CatalogItem careerQuestion = CatalogItem(
  name: 'CareerQuestion',
  dataSchema: S.object(
    description: 'A component representing a single interactive question generated dynamically by the AI to profile the user.',
    properties: {
      'questionId': S.string(description: 'The unique ID for the question (e.g. q1, q2, q3)'),
      'question': S.string(description: 'The question text to show to the user'),
      'options': S.list(
        items: S.string(),
        description: 'The multiple-choice options for the user to select from',
      ),
    },
    required: ['questionId', 'question', 'options'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, dynamic>;
    final questionId = data['questionId'] as String? ?? 'q';
    final question = data['question'] as String? ?? '';
    final optionsRaw = data['options'] as List<dynamic>? ?? [];
    final options = optionsRaw.map((e) => e.toString()).toList();
    
    return _CareerQuestionWidget(
      itemContext: itemContext,
      questionId: questionId,
      question: question,
      options: options,
    );
  },
);

class _CareerQuestionWidget extends StatefulWidget {
  final CatalogItemContext itemContext;
  final String questionId;
  final String question;
  final List<String> options;

  const _CareerQuestionWidget({
    required this.itemContext,
    required this.questionId,
    required this.question,
    required this.options,
  });

  @override
  State<_CareerQuestionWidget> createState() => _CareerQuestionWidgetState();
}

class _CareerQuestionWidgetState extends State<_CareerQuestionWidget> {
  String? _selectedOption;

  @override
  void initState() {
    super.initState();
    if (widget.options.isNotEmpty) {
      _selectedOption = widget.options.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, color: AppTheme.secondaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Career Profile Inquiry',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.question,
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.options.map((option) {
                final isSelected = _selectedOption == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : theme.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedOption = option);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedOption == null
                    ? null
                    : () {
                        widget.itemContext.dispatchEvent(
                          UserActionEvent(
                            name: 'submitAnswer',
                            sourceComponentId: widget.itemContext.id,
                            context: {
                              'questionId': widget.questionId,
                              'question': widget.question,
                              'selectedOption': _selectedOption,
                            },
                          ),
                        );
                      },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Submit Answer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CONSTRUCT THE ENTIRE CATALOG REGISTRY ---

final Catalog basicCatalog = BasicCatalogItems.asCatalog();

final Catalog careerPilotCatalog = basicCatalog.copyWith(
  catalogId: 'careerPilotCatalog',
  newItems: [
    timelineItem,
    skillChecklistItem,
    skillCompareItem,
    projectSuggestionsItem,
    resumeAnalysisItem,
    interviewQuestionsItem,
    careerQuestionnaire,
    careerQuestion,
  ],
);
