import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models/analysis_result.dart';
import '../models/scan_record.dart';
import '../services/history_service.dart';
import '../widgets/scan_record_tile.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.historyService});

  final HistoryService? historyService;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryService _historyService;
  List<ScanRecord> _records = const [];
  bool _loading = true;
  String? _error;

  // Search & Filter state
  String _searchQuery = '';
  RiskLevel? _selectedFilter; // null = All
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _historyService = widget.historyService ?? HistoryService();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    if (mounted) setState(() => _loading = true);
    try {
      final records = await _historyService.getRecords();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load scan history from this device.';
      });
    }
  }

  List<ScanRecord> get _filteredRecords {
    return _records.where((record) {
      if (_selectedFilter != null && record.riskLevel != _selectedFilter) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesContent = record.content.toLowerCase().contains(query);
        final matchesSummary = record.summary.toLowerCase().contains(query);
        final matchesFinding = record.findings.any(
          (f) =>
              f.title.toLowerCase().contains(query) ||
              f.description.toLowerCase().contains(query),
        );
        return matchesContent || matchesSummary || matchesFinding;
      }
      return true;
    }).toList();
  }

  Future<void> _openRecord(ScanRecord record) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          decodedContent: record.content,
          analysisOverride: record.toAnalysisResult(),
          historyService: _historyService,
          returnLabel: 'Back to history',
        ),
      ),
    );
    await _loadRecords();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded,
            color: QRGuardTheme.caution),
        title: const Text('Clear scan history?'),
        content: const Text(
          'This removes QRGuard scan records stored on this device. It does not affect other app data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _historyService.clearHistory();
      await _loadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan history cleared.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not clear scan history.')),
      );
    }
  }

  void _exportHistory() {
    if (_records.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: QRGuardTheme.navyLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.download_rounded, color: QRGuardTheme.teal),
                const SizedBox(width: 8),
                Text(
                  'Export Scan History',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        color: QRGuardTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded, color: QRGuardTheme.teal),
              title: const Text('Export as CSV'),
              subtitle: const Text('Compatible with Excel and Google Sheets'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _copyCsv();
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded, color: QRGuardTheme.teal),
              title: const Text('Export as JSON'),
              subtitle: const Text('Structured developer audit format'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _copyJson();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _copyCsv() {
    final buffer = StringBuffer('Date,Risk,URL_or_Content,Summary\n');
    for (final r in _records) {
      final safeContent = '"${r.content.replaceAll('"', '""')}"';
      final safeSummary = '"${r.summary.replaceAll('"', '""')}"';
      buffer.writeln(
          '${r.scannedAt.toIso8601String()},${r.riskLevel.name},$safeContent,$safeSummary');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV history copied to clipboard!')),
    );
  }

  void _copyJson() {
    final list = _records.map((r) => r.toJson()).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(list);
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON history copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            tooltip: 'Export scan history',
            onPressed: _records.isEmpty || _loading ? null : _exportHistory,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: 'Clear scan history',
            onPressed: _records.isEmpty || _loading ? null : _confirmClear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _loadRecords)
                : _records.isEmpty
                    ? const _EmptyHistory()
                    : RefreshIndicator(
                        onRefresh: _loadRecords,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          itemCount: filtered.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      '${_records.length} ${_records.length == 1 ? 'scan' : 'scans'} stored on this device',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              color: QRGuardTheme.textSecondary),
                                    ),
                                  ),
                                  // Search Field
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (val) =>
                                        setState(() => _searchQuery = val),
                                    decoration: InputDecoration(
                                      hintText: 'Search scans or findings...',
                                      prefixIcon: const Icon(Icons.search_rounded,
                                          size: 20),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear_rounded,
                                                  size: 18),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() => _searchQuery = '');
                                              },
                                            )
                                          : null,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Filter Chips
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _filterChip(
                                            label: 'All',
                                            selected: _selectedFilter == null,
                                            onSelected: () => setState(
                                                () => _selectedFilter = null)),
                                        const SizedBox(width: 8),
                                        _filterChip(
                                            label: 'High Risk',
                                            color: QRGuardTheme.highRisk,
                                            selected: _selectedFilter ==
                                                RiskLevel.high,
                                            onSelected: () => setState(() =>
                                                _selectedFilter =
                                                    RiskLevel.high)),
                                        const SizedBox(width: 8),
                                        _filterChip(
                                            label: 'Caution',
                                            color: QRGuardTheme.caution,
                                            selected: _selectedFilter ==
                                                RiskLevel.medium,
                                            onSelected: () => setState(() =>
                                                _selectedFilter =
                                                    RiskLevel.medium)),
                                        const SizedBox(width: 8),
                                        _filterChip(
                                            label: 'Low Risk',
                                            color: QRGuardTheme.safe,
                                            selected: _selectedFilter ==
                                                RiskLevel.low,
                                            onSelected: () => setState(() =>
                                                _selectedFilter =
                                                    RiskLevel.low)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }
                            final record = filtered[index - 1];
                            return ScanRecordTile(
                              record: record,
                              onTap: () => _openRecord(record),
                            );
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: (color ?? QRGuardTheme.teal).withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: selected
            ? (color ?? QRGuardTheme.teal)
            : QRGuardTheme.textSecondary,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_rounded,
                  size: 60, color: QRGuardTheme.textFaded),
              const SizedBox(height: 18),
              Text(
                'No scans yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: QRGuardTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'QR codes you analyze will appear here.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: QRGuardTheme.caution),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
