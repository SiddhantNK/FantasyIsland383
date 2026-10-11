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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Replanning Audit History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMain,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Immutable chronological audit trail of all plan revisions and disruptions',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _loadHistory,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                ),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.roseSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.rose, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Failed to load history: $_error', style: const TextStyle(color: AppTheme.rose, fontSize: 13)),
                    ),
                  ],
                ),
              )
            else if (_history.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.history_toggle_off_rounded, size: 36, color: AppTheme.textDim),
                      SizedBox(height: 10),
                      Text(
                        'No replanning events recorded yet.',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Confirm an incident from the Dispatcher Console to record history.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                separatorBuilder: (context, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final h = _history[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
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
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.history_rounded, color: AppTheme.primary, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Plan #${h.oldPlanId ?? "?"} → Plan #${h.newPlanId ?? "?"}',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textMain,
                                    ),
                                  ),
                                  if (h.disruptionId != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.amberSoft,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        'Disruption #${h.disruptionId}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.amber,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    h.createdAt.length > 19
                                        ? h.createdAt.substring(0, 19).replaceAll('T', ' ')
                                        : h.createdAt,
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textDim),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                h.summary,
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
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
