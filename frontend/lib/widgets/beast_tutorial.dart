import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/beast_tokens.dart';

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;

  const TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class BeastTutorial {
  static List<TutorialStep> getStepsForRole(String role) {
    switch (role.toUpperCase()) {
      case 'STUDENT':
        return const [
          TutorialStep(
            title: "Welcome to Student Portal",
            description: "Your unified digital campus hub. Review today's schedule, deadlines, and academic notices in one place.",
            icon: Icons.dashboard_outlined,
          ),
          TutorialStep(
            title: "Today's Schedule & Timetable",
            description: "Check lecture timings, room allocations, and faculty details for your enrolled batch across the week.",
            icon: Icons.calendar_month_outlined,
          ),
          TutorialStep(
            title: "Coursework & Assignments",
            description: "Track upcoming submissions, upload solutions, and review faculty evaluations and grades.",
            icon: Icons.assignment_outlined,
          ),
          TutorialStep(
            title: "Real-Time Attendance Register",
            description: "Monitor your aggregate and subject-wise attendance percentages to ensure eligibility requirements are met.",
            icon: Icons.verified_user_outlined,
          ),
          TutorialStep(
            title: "Study Material Library",
            description: "Access curated lecture notes, reference PDFs, and problem sets uploaded directly by your teachers.",
            icon: Icons.menu_book_outlined,
          ),
          TutorialStep(
            title: "Examination Results",
            description: "View published exam schedules and detailed subject scorecards with faculty feedback.",
            icon: Icons.emoji_events_outlined,
          ),
          TutorialStep(
            title: "Academic Doubts Desk",
            description: "Submit questions directly to your subject teachers and receive clear explanatory answers.",
            icon: Icons.help_outline_rounded,
          ),
        ];

      case 'TEACHER':
        return const [
          TutorialStep(
            title: "Faculty Operational Hub",
            description: "Overview of your assigned batches, today's schedule, pending doubts, and submissions to grade.",
            icon: Icons.co_present_outlined,
          ),
          TutorialStep(
            title: "Daily Attendance Marking",
            description: "Take quick roll-call for your scheduled classes with instant batch toggles (Present, Absent, Late).",
            icon: Icons.checklist_rounded,
          ),
          TutorialStep(
            title: "Assignments & Grading Studio",
            description: "Create coursework with due dates, review student submissions, and assign scores and remarks.",
            icon: Icons.assignment_turned_in_outlined,
          ),
          TutorialStep(
            title: "Doubt Resolution Desk",
            description: "Answer questions submitted by your students to provide academic clarification.",
            icon: Icons.question_answer_outlined,
          ),
          TutorialStep(
            title: "Examination Marks Entry",
            description: "Enter and publish exam scores for enrolled students using a spreadsheet-style rapid data grid.",
            icon: Icons.grade_outlined,
          ),
          TutorialStep(
            title: "Applicant Verification",
            description: "Review incoming student admission requests, inspect academic background, and recommend approvals.",
            icon: Icons.how_to_reg_outlined,
          ),
        ];

      case 'ADMIN':
        return const [
          TutorialStep(
            title: "Operational Command Center",
            description: "Real-time metrics on student enrollment, active batches, fee collections, and institution activity.",
            icon: Icons.admin_panel_settings_outlined,
          ),
          TutorialStep(
            title: "Student Directory Lifecycle",
            description: "Search, inspect, suspend, restore, archive, and manage subscription tiers for enrolled students.",
            icon: Icons.people_outline_rounded,
          ),
          TutorialStep(
            title: "Academics & Batches Structure",
            description: "Configure the academic hierarchy: Sessions, Classes, Batches, Subjects, and Faculty assignments.",
            icon: Icons.account_tree_outlined,
          ),
          TutorialStep(
            title: "Admission Requests Pipeline",
            description: "Review multi-tier onboarding applications from students, teachers, and staff with full audit trails.",
            icon: Icons.assignment_ind_outlined,
          ),
          TutorialStep(
            title: "Fee Collections & Ledger",
            description: "Track tuition demands, overdue balances, and record manual payments via Cash, UPI, or Bank Transfer.",
            icon: Icons.payments_outlined,
          ),
          TutorialStep(
            title: "Campus Circulars & Notices",
            description: "Publish institutional circulars, exam dates, and emergency alerts across the institution.",
            icon: Icons.campaign_outlined,
          ),
          TutorialStep(
            title: "Forensic Audit & Security",
            description: "Inspect tamper-evident system logs tracking every administrative action and security event.",
            icon: Icons.security_outlined,
          ),
        ];

      case 'SUPER_ADMIN':
      default:
        return const [
          TutorialStep(
            title: "Institutional Control Center",
            description: "Master governance layer with unrestricted oversight of institutional operations and personnel.",
            icon: Icons.hub_outlined,
          ),
          TutorialStep(
            title: "Multi-Tier Request Authorizations",
            description: "Execute final institutional authorizations for students, teachers, and administrative personnel.",
            icon: Icons.verified_outlined,
          ),
          TutorialStep(
            title: "Administrator Directory",
            description: "Provision, manage, suspend, and audit administrative personnel across the academy.",
            icon: Icons.manage_accounts_outlined,
          ),
          TutorialStep(
            title: "Student Governance",
            description: "Full directory access with account status and subscription management authority.",
            icon: Icons.groups_outlined,
          ),
          TutorialStep(
            title: "Academic Architecture",
            description: "Master structure governance across sessions, streams, batches, and curricula.",
            icon: Icons.school_outlined,
          ),
          TutorialStep(
            title: "Comprehensive Audit Ledger",
            description: "Review forensic audit trails with actor details, timestamps, IP addresses, and data diffs.",
            icon: Icons.find_in_page_outlined,
          ),
          TutorialStep(
            title: "Security & Access Integrity",
            description: "Ensure server-side RBAC integrity, active sessions, and database consistency.",
            icon: Icons.lock_outline_rounded,
          ),
        ];
    }
  }

  static Future<void> showIfFirstTime(BuildContext context, String role) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'beast_tutorial_seen_${role.toLowerCase()}';
    final hasSeen = prefs.getBool(key) ?? false;

    if (!hasSeen && context.mounted) {
      replay(context, role);
    }
  }

  static void replay(BuildContext context, String role) {
    final steps = getStepsForRole(role);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _TutorialDialog(role: role, steps: steps),
    );
  }
}

class _TutorialDialog extends StatefulWidget {
  final String role;
  final List<TutorialStep> steps;

  const _TutorialDialog({required this.role, required this.steps});

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  int _currentIndex = 0;

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'beast_tutorial_seen_${widget.role.toLowerCase()}';
    await prefs.setBool(key, true);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentIndex];
    final isLast = _currentIndex == widget.steps.length - 1;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeastRadius.lg),
      ),
      backgroundColor: BeastColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(BeastSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Step indicator + Skip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: BeastColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(BeastRadius.full),
                    ),
                    child: Text(
                      'STEP ${_currentIndex + 1} OF ${widget.steps.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: BeastColors.dark900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _completeTutorial,
                    style: TextButton.styleFrom(
                      foregroundColor: BeastColors.textMuted,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Skip Tour'),
                  ),
                ],
              ),
              const SizedBox(height: BeastSpacing.xl),

              // Visual Icon Container
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: BeastColors.peach100,
                    shape: BoxShape.circle,
                    border: Border.all(color: BeastColors.peach400, width: 1.5),
                  ),
                  child: Center(
                    child: Icon(
                      step.icon,
                      size: 32,
                      color: BeastColors.dark900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: BeastSpacing.lg),

              // Title & Description
              Text(
                step.title,
                style: BeastTypography.headline.copyWith(fontSize: 19),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BeastSpacing.sm),
              Text(
                step.description,
                style: BeastTypography.body.copyWith(
                  color: BeastColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BeastSpacing.xxl),

              // Progress Bar Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.steps.length, (idx) {
                  final active = idx == _currentIndex;
                  return AnimatedContainer(
                    duration: BeastMotion.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? BeastColors.brandPrimary : BeastColors.neutral200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: BeastSpacing.xl),

              // Navigation Buttons
              Row(
                children: [
                  if (_currentIndex > 0) ...[
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _currentIndex--);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BeastColors.textPrimary,
                        side: const BorderSide(color: BeastColors.borderStrong),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BeastRadius.sm),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: BeastSpacing.lg,
                          vertical: BeastSpacing.md,
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: BeastSpacing.md),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLast) {
                          _completeTutorial();
                        } else {
                          setState(() => _currentIndex++);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BeastColors.brandPrimary,
                        foregroundColor: BeastColors.textOnDark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BeastRadius.sm),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: BeastSpacing.md),
                      ),
                      child: Text(
                        isLast ? 'Get Started' : 'Next',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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
