import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../widgets/app_card.dart';

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
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search subjects, notices, materials...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _results = null);
              },
            ),
        ],
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : _results == null
              ? const Center(
                  child: Text(
                    'Type at least 2 characters to search across academy records.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : !hasAnyResults
                  ? const EmptyStateView(
                      icon: Icons.search_off,
                      title: 'No matching academic records',
                      description: 'Check spelling or try a different subject, chapter, or keyword.',
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (subjects.isNotEmpty) ...[
                          const Text('Subjects', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 6),
                          ...subjects.map((s) => ListTile(
                                leading: const Icon(Icons.book_outlined, color: AppColors.primary),
                                title: Text(s['name'] ?? ''),
                                subtitle: Text('${s['code']} • ${s['class_name']}'),
                              )),
                          const SizedBox(height: 14),
                        ],
                        if (materials.isNotEmpty) ...[
                          const Text('Study Materials', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 6),
                          ...materials.map((m) => ListTile(
                                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                title: Text(m['title'] ?? ''),
                                subtitle: Text('${m['subject_name']} • ${m['chapter'] ?? "General"}'),
                              )),
                          const SizedBox(height: 14),
                        ],
                        if (assignments.isNotEmpty) ...[
                          const Text('Assignments', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 6),
                          ...assignments.map((a) => ListTile(
                                leading: const Icon(Icons.assignment_outlined, color: Colors.blue),
                                title: Text(a['title'] ?? ''),
                                subtitle: Text('${a['subject_name']} • Deadline: ${a['deadline']}'),
                              )),
                          const SizedBox(height: 14),
                        ],
                        if (notices.isNotEmpty) ...[
                          const Text('Notices', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 6),
                          ...notices.map((n) => ListTile(
                                leading: const Icon(Icons.campaign_outlined, color: Colors.orange),
                                title: Text(n['title'] ?? ''),
                                subtitle: Text('Category: ${n['category']} • Published: ${n['publish_date']}'),
                              )),
                          const SizedBox(height: 14),
                        ],
                        if (doubts.isNotEmpty) ...[
                          const Text('Doubts (DoubtDeck)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 6),
                          ...doubts.map((d) => ListTile(
                                leading: const Icon(Icons.help_outline, color: AppColors.secondary),
                                title: Text(d['title'] ?? ''),
                                subtitle: Text('${d['subject_name']} • Status: ${d['status']}'),
                              )),
                          const SizedBox(height: 14),
                        ],
                        if (students.isNotEmpty) ...[
                          const Text('Enrolled Students', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 6),
                          ...students.map((st) => ListTile(
                                leading: const Icon(Icons.person_outline, color: AppColors.primaryLight),
                                title: Text(st['name'] ?? ''),
                                subtitle: Text('ID: ${st['student_id_number']} • Batch: ${st['batch_name']}'),
                              )),
                        ],
                      ],
                    ),
    );
  }
}
