import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryModel> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiService.getHistory();
      if (mounted) {
        setState(() {
          _history = items.reversed.toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 500;

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 24,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit History',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMain,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Chronological trail of all plan revisions',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadHistory,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppTheme.textMuted,
                  tooltip: 'Refresh',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceElevated,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Content ─────────────────────────────────────
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppTheme.primary),
                ),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.roseSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.rose, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Failed to load: $_error',
                          style: const TextStyle(
                              color: AppTheme.rose, fontSize: 13)),
                    ),
                  ],
                ),
              )
            else if (_history.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_toggle_off_rounded,
                            size: 28, color: AppTheme.textDim),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No events yet',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Confirm an incident to see replanning history.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final h = _history[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: AppTheme.shadowSm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.history_rounded,
                              color: AppTheme.primary, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Plan #${h.oldPlanId ?? "?"} → #${h.newPlanId ?? "?"}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textMain,
                                      ),
                                    ),
                                  ),
                                  if (h.disruptionId != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.amberSoft,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: AppTheme.amber
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        'D#${h.disruptionId}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.amber,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                h.summary,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.textSecondary,
                                    height: 1.35),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                h.createdAt.length > 19
                                    ? h.createdAt
                                        .substring(0, 19)
                                        .replaceAll('T', ' ')
                                    : h.createdAt,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textDim),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
