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
  bool _loadingComparison = false;
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
    if (widget.plan?.id == null || widget.plan!.parentPlanId == null) {
      setState(() => _comparison = null);
      return;
    }
    setState(() => _loadingComparison = true);
    try {
      final comp = await ApiService.getPlanComparison(widget.plan!.id!);
      if (mounted) {
        setState(() {
          _comparison = comp;
          _loadingComparison = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComparison = false);
    }
  }

  Future<void> _handleConfirmIncident(DisruptionModel inc) async {
    setState(() => _actionInProgress = true);
    try {
      await ApiService.confirmIncident(inc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emerald,
            content: Text('Incident #${inc.id} confirmed! Revised route plan generated.'),
          ),
        );
      }
      await _loadPendingIncidents();
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.rose,
            content: Text('Cannot Confirm: $msg'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleRejectIncident(DisruptionModel inc) async {
    setState(() => _actionInProgress = true);
    try {
      await ApiService.rejectIncident(inc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Incident #${inc.id} rejected.')),
        );
      }
      await _loadPendingIncidents();
      widget.onRefresh();
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
          const SnackBar(backgroundColor: AppTheme.emerald, content: Text('Initial route plan generated!')),
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
          const SnackBar(content: Text('State reset successfully.')),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dispatcher Header & Controls
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Dispatcher Command Center',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary),
                        ),
                        child: Text(
                          plan != null ? 'Plan Version #${plan.version}' : 'No Active Plan',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryLight),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Incident review, deterministic optimization, and fleet route management',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const Spacer(),
              // Demo / Action Buttons
              OutlinedButton.icon(
                onPressed: _actionInProgress ? null : _handleReset,
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reset Demo'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _actionInProgress ? null : (plan == null ? _handleInitialPlan : widget.onRefresh),
                icon: Icon(plan == null ? Icons.play_arrow : Icons.refresh, size: 16),
                label: Text(plan == null ? 'Generate Plan' : 'Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // PENDING DISRUPTIONS REVIEW INBOX
          Row(
            children: [
              const Icon(Icons.inbox_outlined, color: AppTheme.amber, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Pending Disruptions Queue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _pendingIncidents.isNotEmpty ? AppTheme.amber.withOpacity(0.2) : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _pendingIncidents.isNotEmpty ? AppTheme.amber : AppTheme.border),
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
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Check Inbox'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_loadingPending)
            const Center(child: CircularProgressIndicator())
          else if (_pendingIncidents.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.emerald, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'No pending disruptions. Fleet operations running normally.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
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

          const SizedBox(height: 28),

          // REPLAN DIFF / PLAN COMPARISON
          if (_comparison != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.compare_arrows, color: AppTheme.primaryLight, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Replan Changes: Plan #${_comparison!.parentPlanId} ➔ Plan #${_comparison!.planId}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Count pills
                  Row(
                    children: [
                      _countBadge('KEPT', _comparison!.counts['KEPT'] ?? 0, AppTheme.emerald),
                      const SizedBox(width: 10),
                      _countBadge('MOVED', _comparison!.counts['MOVED'] ?? 0, AppTheme.amber),
                      const SizedBox(width: 10),
                      _countBadge('COMPLETED', _comparison!.counts['COMPLETED'] ?? 0, AppTheme.indigo),
                      const SizedBox(width: 10),
                      _countBadge('BROKEN', _comparison!.counts['BROKEN'] ?? 0, AppTheme.rose),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 8),
                  const Text('Detailed Order Changes & Explanations:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  ..._comparison!.changes.map((ch) {
                    final status = ch['status'] ?? '';
                    final reason = ch['reason'] ?? '';
                    Color color;
                    switch (status) {
                      case 'BROKEN':
                        color = AppTheme.rose;
                        break;
                      case 'MOVED':
                        color = AppTheme.amber;
                        break;
                      case 'COMPLETED':
                        color = AppTheme.emerald;
                        break;
                      default:
                        color = AppTheme.textDim;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: color.withOpacity(0.6)),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${ch['order_id']}: ',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
                          Expanded(
                            child: Text(reason,
                                style: TextStyle(fontSize: 12, color: color == AppTheme.textDim ? AppTheme.textMuted : color)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],

          // INTERACTIVE NETWORK MAP
          Row(
            children: [
              const Text(
                'Live Network Route Map',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
              ),
              const Spacer(),
              if (_selectedVehicleFilter != null)
                TextButton(
                  onPressed: () => setState(() => _selectedVehicleFilter = null),
                  child: const Text('Show All Vehicles'),
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
          const SizedBox(height: 28),

          // FLEET CAPACITY & VEHICLE CARDS
          const Text(
            'Active Fleet Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
          ),
          const SizedBox(height: 12),
          if (plan != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final cards = plan.vehicles.map((v) {
                  final selected = _selectedVehicleFilter == v.id;
                  final card = GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedVehicleFilter = selected ? null : v.id;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: isNarrow ? 0 : 12, bottom: isNarrow ? 12 : 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : (v.isFailed ? AppTheme.rose.withOpacity(0.5) : AppTheme.border),
                          width: selected ? 2 : 1,
                        ),
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: v.isFailed ? AppTheme.rose.withOpacity(0.2) : AppTheme.emerald.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
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
                          Text('Stops: ${v.stops.length}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          const SizedBox(height: 6),
                          Text('Weight: ${v.pendingWeightKg.toStringAsFixed(0)} / ${v.weightCapKg.toStringAsFixed(0)} kg (${v.weightUtilPct.toStringAsFixed(0)}%)',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (v.weightUtilPct / 100).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: AppTheme.surfaceElevated,
                              valueColor: AlwaysStoppedAnimation(v.isFailed ? AppTheme.rose : AppTheme.primary),
                            ),
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

  Widget _countBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.6)),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasErrors ? AppTheme.rose.withOpacity(0.6) : AppTheme.amber.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: incident.source == 'AI_PARSER' ? AppTheme.indigo.withOpacity(0.2) : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  incident.source,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: incident.source == 'AI_PARSER' ? AppTheme.indigo : AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Incident #${incident.id}: ${incident.eventType}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textMain),
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
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 16,
            children: [
              if (incident.vehicleId != null)
                Text('Vehicle: ${incident.vehicleId}', style: const TextStyle(fontSize: 12, color: AppTheme.textMain)),
              if (incident.locationId != null)
                Text('Location: ${incident.locationId}', style: const TextStyle(fontSize: 12, color: AppTheme.textMain)),
              if (incident.fromLocation != null)
                Text('From: ${incident.fromLocation} ➔ ${incident.toLocation}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMain)),
              if (incident.endTime != null)
                Text('Until: ${incident.endTime}', style: const TextStyle(fontSize: 12, color: AppTheme.textMain)),
            ],
          ),
          if (hasErrors) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.rose.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppTheme.rose, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Validation warning: ${incident.validationErrors.join("; ")}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.rose),
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
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.rose),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Confirm & Re-Optimize'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
