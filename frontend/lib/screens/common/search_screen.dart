import 'package:flutter/material.dart';
import '../../core/theme/beast_tokens.dart';
import '../../core/services/api_service.dart';
import '../../widgets/beast_components.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _api = ApiService();
  final _searchController = TextEditingController();
  bool _searching = false;
  Map<String, dynamic>? _results;

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = null);
      return;
    }

    setState(() => _searching = true);
    final res = await _api.get('/api/search?q=${Uri.encodeComponent(query.trim())}');
    setState(() {
      _searching = false;
      if (res.success && res.data != null) {
        _results = res.data;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _results?['subjects'] as List? ?? [];
    final notices = _results?['notices'] as List? ?? [];
    final materials = _results?['materials'] as List? ?? [];
    final assignments = _results?['assignments'] as List? ?? [];
    final doubts = _results?['doubts'] as List? ?? [];
    final students = _results?['students'] as List? ?? [];

    final hasAnyResults = subjects.isNotEmpty || notices.isNotEmpty || materials.isNotEmpty || assignments.isNotEmpty || doubts.isNotEmpty || students.isNotEmpty;

    return Scaffold(
      backgroundColor: BeastColors.surfaceNeutral,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BeastColors.dark900),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: BeastTypography.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'Search subjects, notices, materials, students...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: BeastColors.dark900),
              onPressed: () {
                _searchController.clear();
                setState(() => _results = null);
              },
            ),
        ],
      ),
      body: _searching
          ? const Center(child: BeastLoadingState(message: 'Searching institutional database...'))
          : _results == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 48, color: BeastColors.neutral400),
                      const SizedBox(height: 12),
                      Text(
                        'Type at least 2 characters to search across academy records.',
                        style: BeastTypography.caption,
                      ),
                    ],
                  ),
                )
              : !hasAnyResults
                  ? const BeastEmptyState(
                      icon: Icons.search_off,
                      title: 'No matching academic records',
                      subtitle: 'Check spelling or try a different subject, chapter, or keyword.',
                    )
                  : ListView(
                      padding: const EdgeInsets.all(BeastSpacing.lg),
                      children: [
                        if (subjects.isNotEmpty) ...[
                          Text('Subjects', style: BeastTypography.h3),
                          const SizedBox(height: 8),
                          ...subjects.map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: BeastCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.book_outlined, color: BeastColors.dark900),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s['name'] ?? '', style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                                            Text('${s['code']} • ${s['class_name']}', style: BeastTypography.caption),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (materials.isNotEmpty) ...[
                          Text('Study Materials', style: BeastTypography.h3),
                          const SizedBox(height: 8),
                          ...materials.map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: BeastCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.picture_as_pdf, color: Colors.red),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(m['title'] ?? '', style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                                            Text('${m['subject_name']} • ${m['chapter'] ?? "General"}', style: BeastTypography.caption),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (assignments.isNotEmpty) ...[
                          Text('Assignments', style: BeastTypography.h3),
                          const SizedBox(height: 8),
                          ...assignments.map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: BeastCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.assignment_outlined, color: Colors.blue),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(a['title'] ?? '', style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                                            Text('${a['subject_name']} • Due: ${a['deadline']}', style: BeastTypography.caption),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (notices.isNotEmpty) ...[
                          Text('Notices', style: BeastTypography.h3),
                          const SizedBox(height: 8),
                          ...notices.map((n) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: BeastCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.campaign_outlined, color: Colors.orange),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(n['title'] ?? '', style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                                            Text('${n['category'].toString().toUpperCase()} • ${n['publish_date']}', style: BeastTypography.caption),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (doubts.isNotEmpty) ...[
                          Text('Doubts (DoubtDeck)', style: BeastTypography.h3),
                          const SizedBox(height: 8),
                          ...doubts.map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: BeastCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.help_outline, color: BeastColors.peach400),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(d['title'] ?? '', style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                                            Text('${d['subject_name']} • Status: ${d['status']}', style: BeastTypography.caption),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (students.isNotEmpty) ...[
                          Text('Enrolled Students', style: BeastTypography.h3),
                          const SizedBox(height: 8),
                          ...students.map((st) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: BeastCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_outline, color: BeastColors.dark900),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(st['name'] ?? '', style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                                            Text('ID: ${st['student_id_number']} • Batch: ${st['batch_name']}', style: BeastTypography.caption),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        ],
                      ],
                    ),
    );
  }
}
