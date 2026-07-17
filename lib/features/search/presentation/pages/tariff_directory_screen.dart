import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/search/presentation/providers/tariff_search_provider.dart';
import 'package:go_router/go_router.dart';

class TariffDirectoryScreen extends ConsumerStatefulWidget {
  const TariffDirectoryScreen({super.key});

  @override
  ConsumerState<TariffDirectoryScreen> createState() => _TariffDirectoryScreenState();
}

class _TariffDirectoryScreenState extends ConsumerState<TariffDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _currentQuery = '';
  int _selectedCategoryIndex = 0;

  final List<String> _categories = [
    'All',
    'Machinery',
    'Textiles',
    'Petroleum',
    'Electronics',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });
    _updateSearch();
  }

  void _updateSearch() {
    final userText = _searchController.text;
    final category = _categories[_selectedCategoryIndex];
    
    // Combine user text with category filter
    // If 'All' is selected, just use user text.
    String effectiveQuery = userText;
    if (category != 'All') {
      effectiveQuery = '$userText $category'.trim();
    }
    
    ref.read(tariffSearchProvider.notifier).updateQuery(effectiveQuery);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(tariffSearchProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? TariffColors.navyMid : const Color(0xFF1565C0),
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tariff Directory',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '6-DIGIT UNIVERSAL MASTER',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withValues(alpha: 0.1), height: 1),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _currentQuery = value);
                _updateSearch();
              },
              style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by HS Code or Product Name...',
                hintStyle: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? TariffColors.textMuted : Colors.grey[400]),
                suffixIcon: _currentQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: isDark ? TariffColors.textMuted : Colors.grey[400]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _currentQuery = '');
                          _updateSearch();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? TariffColors.navySurface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: TariffColors.amberPending, width: 1.5),
                ),
              ),
            ),
          ),
          // Category Filter Chips Bar
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedCategoryIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => _onFilterChanged(index),
                    child: AnimatedScale(
                      scale: isSelected ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? TariffColors.amberPending : (isDark ? TariffColors.navySurface : Colors.grey[200]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? TariffColors.amberPending : (isDark ? TariffColors.cardBorder : Colors.grey[300]!),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _categories[index],
                          style: TextStyle(
                            color: isSelected ? (isDark ? TariffColors.navyDeep : Colors.black87) : (isDark ? TariffColors.textSecondary : Colors.black54),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: searchState.when(
              data: (results) {
                if (results.isEmpty) {
                  return _buildNoResults();
                }
                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return _buildTariffCard(item);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: TariffColors.amberPending),
              ),
              error: (err, _) => _buildErrorState(err.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTariffCard(Map<String, dynamic> item) {
    final hsCode = item['hs_code'] ?? '0000.00';
    final description = item['description'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bool isHighTariff = hsCode.startsWith('85') || hsCode.startsWith('87') || hsCode.startsWith('30');
    final chipColor = isHighTariff ? TariffColors.amberPending : TariffColors.greenVerified;
    final chipBg = isDark 
        ? (isHighTariff ? TariffColors.amberPendingSoft : TariffColors.greenVerifiedSoft)
        : (isHighTariff ? Colors.amber[50]! : Colors.green[50]!);
    final chipBorder = isHighTariff ? TariffColors.amberPendingBorder : TariffColors.greenVerifiedBorder;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? TariffColors.navySurface : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? TariffColors.cardBorder : Colors.grey[200]!, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTariffDetails(context, item),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hsCode,
                        style: TextStyle(
                          color: isDark ? TariffColors.textPrimary : Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          fontFamily: 'monospace',
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildHighlightedText(description, _currentQuery),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: chipBorder.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isHighTariff ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                            size: 11,
                            color: chipColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isHighTariff ? 'HIGH' : 'STD',
                            style: TextStyle(
                              color: chipColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black54, fontSize: 13, height: 1.4),
      );
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + query.length),
        style: TextStyle(
          color: TariffColors.amberPending,
          fontWeight: FontWeight.bold,
          backgroundColor: TariffColors.amberPending.withValues(alpha: 0.15),
        ),
      ));
      start = indexOfMatch + query.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black54, fontSize: 13, height: 1.4, fontFamily: 'Roboto'),
        children: spans,
      ),
    );
  }

  Widget _buildNoResults() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: isDark ? TariffColors.textMuted : Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No matching commodities',
            style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TariffColors.crimsonRiskSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TariffColors.crimsonRiskBorder),
        ),
        child: Text(
          'Search Error: $message',
          style: const TextStyle(color: TariffColors.crimsonRisk),
        ),
      ),
    );
  }

  void _showTariffDetails(BuildContext context, Map<String, dynamic> item) {
    final hsCode = item['hs_code'] ?? '0000.00';
    final description = item['description'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? TariffColors.navyMid : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? TariffColors.navyElevated : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? TariffColors.amberPendingSoft : Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tag_rounded, color: TariffColors.amberPending, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'CLASSIFICATION DATA',
                  style: TextStyle(
                    color: isDark ? TariffColors.textMuted : Colors.grey[600],
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hsCode,
              style: TextStyle(
                color: isDark ? TariffColors.textPrimary : Colors.black87,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'NOMENCLATURE DESCRIPTION',
              style: TextStyle(
                color: isDark ? TariffColors.textMuted : Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(
                color: isDark ? TariffColors.textPrimary : Colors.black87,
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? TariffColors.navyElevated : const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Dismiss Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
