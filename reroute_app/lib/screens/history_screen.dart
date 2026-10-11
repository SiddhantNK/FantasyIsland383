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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Replanning Audit History',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Immutable chronological audit trail of all plan revisions and disruptions',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
                  onPressed: _loadHistory,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.rose.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.rose),
                ),
                child: Text('Failed to load history: $_error', style: const TextStyle(color: AppTheme.rose)),
              )
            else if (_history.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Center(
                  child: Text('No replanning events recorded yet. Confirm an incident to record history.',
                      style: TextStyle(color: AppTheme.textMuted)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final h = _history[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history, color: AppTheme.primaryLight, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Plan #${h.oldPlanId ?? "?"} ➔ Plan #${h.newPlanId ?? "?"}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                                  ),
                                  if (h.disruptionId != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Disruption #${h.disruptionId}',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.amberLight),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    h.createdAt.length > 19 ? h.createdAt.substring(0, 19).replaceAll('T', ' ') : h.createdAt,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textDim),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                h.summary,
                                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
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
