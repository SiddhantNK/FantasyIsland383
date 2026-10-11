import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/route_map_widget.dart';

class DispatcherScreen extends StatefulWidget {
  final PlanModel? plan;
  final List<LocationModel> locations;
  final VoidCallback onRefresh;

  const DispatcherScreen({
    super.key,
    required this.plan,
    required this.locations,
    required this.onRefresh,
  });

  @override
  State<DispatcherScreen> createState() => _DispatcherScreenState();
}

class _DispatcherScreenState extends State<DispatcherScreen> {
  List<DisruptionModel> _pendingIncidents = [];
  PlanComparisonModel? _comparison;
  bool _loadingPending = false;
  bool _actionInProgress = false;
  String? _selectedVehicleFilter;

  @override
  void initState() {
    super.initState();
    _loadPendingIncidents();
    _loadComparisonIfApplicable();
  }

  @override
  void didUpdateWidget(covariant DispatcherScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan?.id != widget.plan?.id) {
      _loadComparisonIfApplicable();
    }
  }

  Future<void> _loadPendingIncidents() async {
    setState(() => _loadingPending = true);
    try {
      final incidents = await ApiService.getIncidents(status: 'PENDING');
      if (mounted) {
        setState(() {
          _pendingIncidents = incidents;
          _loadingPending = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _loadComparisonIfApplicable() async {
    final plan = widget.plan;
    if (plan == null || plan.id == null || plan.parentPlanId == null) {
      if (mounted) setState(() => _comparison = null);
      return;
    }
    try {
      final comp = await ApiService.getPlanComparison(plan.id!);
      if (mounted) {
        setState(() {
          _comparison = comp;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleConfirmIncident(DisruptionModel incident) async {
    setState(() => _actionInProgress = true);
    try {
      await ApiService.confirmIncident(incident.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emerald,
            content: Text('Incident #${incident.id} confirmed! Deterministic replan generated.'),
          ),
        );
      }
      await _loadPendingIncidents();
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.rose, content: Text('Confirm failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleRejectIncident(DisruptionModel incident) async {
    setState(() => _actionInProgress = true);
    try {
      await ApiService.rejectIncident(incident.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Incident #${incident.id} rejected.')),
        );
      }
      await _loadPendingIncidents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.rose, content: Text('Reject failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleInitialPlan() async {
    setState(() => _actionInProgress = true);
    try {
      await ApiService.createInitialPlan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.emerald,
            content: Text('Initial plan computed and dispatched successfully.'),
          ),
        );
      }
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.rose, content: Text('Initial plan failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleReset() async {
    setState(() => _actionInProgress = true);
    try {
      await ApiService.resetDemo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo state reset successfully.')),
        );
      }
      await _loadPendingIncidents();
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.rose, content: Text('Reset failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Top Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Dispatcher Command Center',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: plan != null ? AppTheme.primarySoft : AppTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: plan != null
                                  ? AppTheme.primary.withValues(alpha: 0.3)
                                  : AppTheme.border,
                            ),
                          ),
                          child: Text(
                            plan != null ? 'Plan Version #${plan.version}' : 'No Active Plan',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: plan != null ? AppTheme.primary : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Live incident review, deterministic rerouting, and active fleet tracking',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Action Buttons
              OutlinedButton.icon(
                onPressed: _actionInProgress ? null : _handleReset,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Reset Demo'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _actionInProgress ? null : (plan == null ? _handleInitialPlan : widget.onRefresh),
                icon: Icon(plan == null ? Icons.play_arrow_rounded : Icons.refresh_rounded, size: 16),
                label: Text(plan == null ? 'Generate Plan' : 'Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // PENDING DISRUPTIONS REVIEW INBOX
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _pendingIncidents.isNotEmpty ? AppTheme.amberSoft : AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.inbox_rounded,
                        color: _pendingIncidents.isNotEmpty ? AppTheme.amber : AppTheme.textMuted,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Pending Disruptions Queue',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _pendingIncidents.isNotEmpty ? AppTheme.amberSoft : AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _pendingIncidents.isNotEmpty
                              ? AppTheme.amber.withValues(alpha: 0.3)
                              : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        '${_pendingIncidents.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _pendingIncidents.isNotEmpty ? AppTheme.amber : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _loadPendingIncidents,
                      icon: const Icon(Icons.sync_rounded, size: 15),
                      label: const Text('Check Inbox'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loadingPending)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    ),
                  )
                else if (_pendingIncidents.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle_outline_rounded, color: AppTheme.emerald, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'No pending disruptions. Fleet operations are running on schedule.',
                          style: TextStyle(color: AppTheme.emerald, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                else
                  ..._pendingIncidents.map((inc) => _PendingIncidentCard(
                        incident: inc,
                        onConfirm: () => _handleConfirmIncident(inc),
                        onReject: () => _handleRejectIncident(inc),
                      )),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // REPLAN DIFF / PLAN COMPARISON
          if (_comparison != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
                boxShadow: AppTheme.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.compare_arrows_rounded, color: AppTheme.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Replan Comparison: Plan #${_comparison!.parentPlanId} → Plan #${_comparison!.planId}',
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _countBadge('KEPT', _comparison!.counts['KEPT'] ?? 0, AppTheme.emerald, AppTheme.emeraldSoft),
                      _countBadge('MOVED', _comparison!.counts['MOVED'] ?? 0, AppTheme.amber, AppTheme.amberSoft),
                      _countBadge('COMPLETED', _comparison!.counts['COMPLETED'] ?? 0, AppTheme.indigo, AppTheme.indigoSoft),
                      _countBadge('BROKEN', _comparison!.counts['BROKEN'] ?? 0, AppTheme.rose, AppTheme.roseSoft),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.border, height: 1),
                  const SizedBox(height: 12),
                  const Text(
                    'Order Changes & Reasons:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ..._comparison!.changes.map((ch) {
                    final status = ch['status'] ?? '';
                    final reason = ch['reason'] ?? '';
                    Color color;
                    Color softBg;
                    switch (status) {
                      case 'BROKEN':
                        color = AppTheme.rose;
                        softBg = AppTheme.roseSoft;
                        break;
                      case 'MOVED':
                        color = AppTheme.amber;
                        softBg = AppTheme.amberSoft;
                        break;
                      case 'COMPLETED':
                        color = AppTheme.emerald;
                        softBg = AppTheme.emeraldSoft;
                        break;
                      default:
                        color = AppTheme.textMuted;
                        softBg = AppTheme.surfaceElevated;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: softBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: color.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${ch['order_id']}: ',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                          ),
                          Expanded(
                            child: Text(
                              reason,
                              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // INTERACTIVE NETWORK MAP
          Row(
            children: [
              const Text(
                'Live Network Route Map',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              if (_selectedVehicleFilter != null)
                TextButton.icon(
                  onPressed: () => setState(() => _selectedVehicleFilter = null),
                  icon: const Icon(Icons.clear_rounded, size: 14),
                  label: const Text('Show All Vehicles'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 380,
            child: RouteMapWidget(
              plan: plan,
              locations: widget.locations,
              highlightedVehicleId: _selectedVehicleFilter,
              activeClosures: _pendingIncidents.where((i) => i.eventType == 'ROAD_CLOSURE').toList(),
            ),
          ),
          const SizedBox(height: 24),

          // FLEET CAPACITY & VEHICLE CARDS
          const Text(
            'Active Fleet Overview',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          if (plan != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final cards = plan.vehicles.map((v) {
                  final selected = _selectedVehicleFilter == v.id;
                  final card = InkWell(
                    onTap: () {
                      setState(() {
                        _selectedVehicleFilter = selected ? null : v.id;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: EdgeInsets.only(right: isNarrow ? 0 : 12, bottom: isNarrow ? 12 : 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primarySoft : AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : (v.isFailed ? AppTheme.rose.withValues(alpha: 0.5) : AppTheme.border),
                          width: selected ? 1.6 : 1,
                        ),
                        boxShadow: AppTheme.shadowSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                v.id,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: v.isFailed ? AppTheme.roseSoft : AppTheme.emeraldSoft,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: v.isFailed
                                        ? AppTheme.rose.withValues(alpha: 0.3)
                                        : AppTheme.emerald.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  v.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: v.isFailed ? AppTheme.rose : AppTheme.emerald,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Assigned Stops: ${v.stops.length}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              Text('${v.weightUtilPct.toStringAsFixed(0)}% Utilized',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (v.weightUtilPct / 100).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: AppTheme.surfaceElevated,
                              valueColor: AlwaysStoppedAnimation(v.isFailed ? AppTheme.rose : AppTheme.primary),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Weight: ${v.pendingWeightKg.toStringAsFixed(0)} / ${v.weightCapKg.toStringAsFixed(0)} kg',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                  return isNarrow ? card : Expanded(child: card);
                }).toList();

                return isNarrow ? Column(children: cards) : Row(children: cards);
              },
            ),
        ],
      ),
    );
  }

  Widget _countBadge(String label, int count, Color color, Color softBg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: softBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _PendingIncidentCard extends StatelessWidget {
  final DisruptionModel incident;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  const _PendingIncidentCard({
    required this.incident,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final hasErrors = incident.validationErrors.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasErrors ? AppTheme.rose.withValues(alpha: 0.4) : AppTheme.amber.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: incident.source == 'AI_PARSER' ? AppTheme.indigoSoft : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: incident.source == 'AI_PARSER'
                        ? AppTheme.indigo.withValues(alpha: 0.3)
                        : AppTheme.border,
                  ),
                ),
                child: Text(
                  incident.source,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: incident.source == 'AI_PARSER' ? AppTheme.indigo : AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Incident #${incident.id}: ${incident.eventType}',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textMain),
              ),
              const Spacer(),
              Text(
                'Reported ${incident.incidentTime ?? ""}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (incident.rawText != null) ...[
            Text(
              '"${incident.rawText}"',
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (incident.vehicleId != null)
                Text('Vehicle: ${incident.vehicleId}', style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
              if (incident.locationId != null)
                Text('Location: ${incident.locationId}', style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
              if (incident.fromLocation != null)
                Text('Closure: ${incident.fromLocation} → ${incident.toLocation}',
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
              if (incident.endTime != null)
                Text('Until: ${incident.endTime}', style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            ],
          ),
          if (hasErrors) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.roseSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.rose, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Validation warning: ${incident.validationErrors.join("; ")}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.rose, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.rose,
                  side: BorderSide(color: AppTheme.rose.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                ),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Confirm & Re-Optimize'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
