import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../models/material_notice_model.dart';
import '../../providers/student_provider.dart';
import '../../widgets/beast_components.dart';

class StudentMaterialsScreen extends StatefulWidget {
  const StudentMaterialsScreen({super.key});

  @override
  State<StudentMaterialsScreen> createState() => _StudentMaterialsScreenState();
}

class _StudentMaterialsScreenState extends State<StudentMaterialsScreen> {
  String _searchQuery = '';
  String _selectedSubject = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).fetchMaterials();
    });
  }

  IconData _getFileIcon(String? fileType, String? url) {
    final type = (fileType ?? url ?? '').toLowerCase();
    if (type.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (type.contains('doc') || type.contains('word')) return Icons.description_outlined;
    if (type.contains('http') || type.contains('link')) return Icons.link_rounded;
    if (type.contains('ppt')) return Icons.slideshow_outlined;
    if (type.contains('xls')) return Icons.table_chart_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color _getFileColor(String? fileType, String? url) {
    final type = (fileType ?? url ?? '').toLowerCase();
    if (type.contains('pdf')) return BeastColors.danger;
    if (type.contains('doc')) return BeastColors.info;
    if (type.contains('ppt')) return BeastColors.warning;
    return BeastColors.dark900;
  }

  @override
  Widget build(BuildContext context) {
    final student = Provider.of<StudentProvider>(context);

    // Extract unique subjects
    final subjects = {'ALL', ...student.materials.map((m) => m.subjectName ?? 'General').where((s) => s.isNotEmpty)};

    final filtered = student.materials.where((m) {
      final matchesSubject = _selectedSubject == 'ALL' || (m.subjectName ?? 'General') == _selectedSubject;
      if (!matchesSubject) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return m.title.toLowerCase().contains(q) ||
          (m.chapter?.toLowerCase().contains(q) ?? false) ||
          (m.subjectName?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Study Materials Repository'),
      ),
      body: student.isLoading && student.materials.isEmpty
          ? const BeastLoadingState(message: 'Loading study library...')
          : student.errorMessage != null && student.materials.isEmpty
              ? BeastErrorState(
                  message: student.errorMessage!,
                  onRetry: () => student.fetchMaterials(),
                )
              : Column(
                  children: [
                    // Search & Subject Filter Bar
                    Container(
                      color: BeastColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg, vertical: BeastSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search chapters, topics, formulas...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () => setState(() => _searchQuery = ''),
                                    )
                                  : null,
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          ),
                          if (subjects.length > 2) ...[
                            const SizedBox(height: BeastSpacing.sm),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: subjects.map((sub) {
                                  final isSel = _selectedSubject == sub;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(sub),
                                      selected: isSel,
                                      selectedColor: BeastColors.peach200,
                                      backgroundColor: BeastColors.neutral100,
                                      labelStyle: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                        color: isSel ? BeastColors.dark900 : BeastColors.textSecondary,
                                      ),
                                      onSelected: (_) => setState(() => _selectedSubject = sub),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(color: BeastColors.borderSubtle, height: 1),

                    Expanded(
                      child: filtered.isEmpty
                          ? BeastEmptyState(
                              icon: Icons.menu_book_outlined,
                              title: _searchQuery.isEmpty ? 'No Materials Available' : 'No Matching Resources',
                              message: _searchQuery.isEmpty
                                  ? 'Curated reference notes, formulas, and PDFs will appear here when uploaded.'
                                  : 'No materials matched "$_searchQuery".',
                            )
                          : RefreshIndicator(
                              onRefresh: () => student.fetchMaterials(),
                              color: BeastColors.brandPrimary,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(BeastSpacing.lg),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                                itemBuilder: (ctx, i) => _buildMaterialCard(filtered[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMaterialCard(StudyMaterialModel mat) {
    final iconColor = _getFileColor(mat.fileType, mat.fileUrl);
    final icon = _getFileIcon(mat.fileType, mat.fileUrl);

    return BeastCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(BeastSpacing.md),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BeastRadius.sm),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: BeastSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: BeastColors.surfaceWarm,
                        borderRadius: BorderRadius.circular(BeastRadius.xs),
                      ),
                      child: Text(
                        mat.subjectName ?? 'Subject',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: BeastColors.dark900,
                        ),
                      ),
                    ),
                    if (mat.fileSize > 0)
                      Text(
                        '${(mat.fileSize / 1024).toStringAsFixed(1)} KB',
                        style: BeastTypography.caption,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(mat.title, style: BeastTypography.title.copyWith(fontSize: 15)),
                if (mat.chapter != null && mat.chapter!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Chapter: ${mat.chapter}', style: BeastTypography.caption),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Uploaded: ${(mat.createdAt != null && mat.createdAt!.length >= 10) ? mat.createdAt!.substring(0, 10) : (mat.createdAt ?? "Recently")}',
                      style: BeastTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: BeastColors.dark900),
            tooltip: 'Open Material',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening resource: ${mat.title}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
