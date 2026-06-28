import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:careerpilot_ai/core/theme/app_theme.dart';
import 'package:careerpilot_ai/providers/auth_provider.dart';
import 'package:careerpilot_ai/providers/career_provider.dart';
import 'package:careerpilot_ai/models/roadmap.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final roadmapsAsync = ref.watch(roadmapsListProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final firstName = (user.displayName ?? 'there').split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CareerPilot AI',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(roadmapsListProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Welcome ──────────────────────────────────────────
                Text(
                  'Hey, $firstName 👋',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.currentPath != null
                      ? 'Targeting: ${user.currentPath}'
                      : 'Ready to grow your career today?',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Stats Row ─────────────────────────────────────────
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.local_fire_department,
                      iconColor: Colors.orange,
                      value: '${user.streak}',
                      label: 'Day Streak',
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.stars_rounded,
                      iconColor: AppTheme.secondaryColor,
                      value: '${user.roadmapsCompleted}',
                      label: 'Completed',
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Quick Actions ─────────────────────────────────────
                Text(
                  'Quick Actions',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _PromptChip(
                        label: 'New Roadmap',
                        icon: Icons.map_outlined,
                        onTap: () => _navigateToChat(context, ref,
                            'Create a personalized career roadmap for me.'),
                      ),
                      _PromptChip(
                        label: 'Skill Gap',
                        icon: Icons.analytics_outlined,
                        onTap: () => _navigateToChat(context, ref,
                            'Analyze my skill gap and suggest what to learn next.'),
                      ),
                      _PromptChip(
                        label: 'Interview Prep',
                        icon: Icons.question_answer_outlined,
                        onTap: () => _navigateToChat(context, ref,
                            'Give me interview practice questions for my target role.'),
                      ),
                      _PromptChip(
                        label: 'Project Ideas',
                        icon: Icons.lightbulb_outline,
                        onTap: () => _navigateToChat(context, ref,
                            'Suggest portfolio project ideas to boost my profile.'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Active Roadmaps ───────────────────────────────────
                roadmapsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => const SizedBox.shrink(),
                  data: (roadmaps) {
                    if (roadmaps.isEmpty) return _buildEmptyState(context);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My Roadmaps',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.go('/roadmaps'),
                              child: Text(
                                'View all',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...roadmaps
                            .take(3)
                            .map((r) => _buildRoadmapCard(context, ref, r)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context, WidgetRef ref, String prompt) {
    ref.read(chatPromptProvider.notifier).state = prompt;
    context.go('/chat');
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(
              Icons.map_outlined,
              size: 56,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No roadmaps yet',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask the AI Coach to build your first one.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/chat'),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Ask AI Coach'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapCard(
      BuildContext context, WidgetRef ref, CareerRoadmap roadmap) {
    final theme = Theme.of(context);
    final progress = roadmap.progress;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: () {
          ref.read(activeRoadmapIdProvider.notifier).state = roadmap.id;
          context.push('/roadmap/${roadmap.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      roadmap.title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      roadmap.estimatedDuration,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor:
                            AppTheme.primaryColor.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Prompt Chip ───────────────────────────────────────────────────────────────
class _PromptChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PromptChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        avatar: Icon(icon, size: 15, color: AppTheme.primaryColor),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: theme.colorScheme.surface,
        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.15)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
