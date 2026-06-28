import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:careerpilot_ai/core/theme/app_theme.dart';
import 'package:careerpilot_ai/providers/auth_provider.dart';
import 'package:careerpilot_ai/providers/career_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class RoadmapScreen extends ConsumerWidget {
  final String roadmapId;

  const RoadmapScreen({
    super.key,
    required this.roadmapId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final roadmapAsync = ref.watch(activeRoadmapProvider);

    // Ensure state activeId is updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(activeRoadmapIdProvider) != roadmapId) {
        ref.read(activeRoadmapIdProvider.notifier).state = roadmapId;
      }
    });

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roadmap Details'),
      ),
      body: roadmapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading roadmap: $err')),
        data: (roadmap) {
          if (roadmap == null) {
            return const Center(child: Text('Roadmap not found.'));
          }

          final progressPercent = roadmap.progress;

          return Column(
            children: [
              // Header Card showing title and overall progress
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.06))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roadmap.title,
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estimated Duration: ${roadmap.estimatedDuration}',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.55)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressPercent,
                              minHeight: 6, // Sleeker
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${(progressPercent * 100).toInt()}% Done',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Milestones List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: roadmap.milestones.length,
                  itemBuilder: (context, idx) {
                    final milestone = roadmap.milestones[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        initiallyExpanded: idx == 0,
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                          foregroundColor: AppTheme.secondaryColor,
                          child: Text(
                            'W${milestone.weekNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        title: Text(
                          milestone.title,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  milestone.description,
                                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Weekly Tasks',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                 ...milestone.tasks.map((task) {
                                  final youtubeUrl = task.resources.firstWhere(
                                    (r) => r.startsWith('http'),
                                    orElse: () => '',
                                  );

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CheckboxListTile(
                                          title: Text(task.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                          value: task.isCompleted,
                                          activeColor: AppTheme.primaryColor,
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity: ListTileControlAffinity.leading,
                                          onChanged: (val) async {
                                            if (val != null) {
                                              await ref.read(careerRepositoryProvider).updateRoadmapTaskCompletion(
                                                user.id,
                                                roadmap.id,
                                                milestone.id,
                                                task.id,
                                                val,
                                              );
                                              // Force reload list and active item
                                              ref.invalidate(roadmapsListProvider);
                                              ref.invalidate(activeRoadmapProvider);
                                            }
                                          },
                                        ),
                                        if (youtubeUrl.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 32.0),
                                            child: ActionChip(
                                              avatar: const Icon(Icons.play_circle_fill, color: Colors.red, size: 16),
                                              label: Text(
                                                'Watch Tutorial (${user.preferredLanguages.join(", ")})',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                              backgroundColor: Colors.red.withOpacity(0.05),
                                              side: BorderSide(color: Colors.red.withOpacity(0.15)),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              onPressed: () async {
                                                final uri = Uri.parse(youtubeUrl);
                                                try {
                                                  final launched = await launchUrl(
                                                    uri,
                                                    mode: LaunchMode.externalApplication,
                                                  );
                                                  if (!launched && context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Could not open YouTube link.')),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Error launching link: $e')),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
