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
            content: Text('Incident #${incident.id} confirmed! Replan generated.'),
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
            content: Text('Initial plan generated successfully.'),
          ),
        );
      }
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.rose, content: Text('Plan failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleReset() async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reset Demo?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will clear all plans, incidents, and history. This cannot be undone.',
          style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

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
    final isCompact = MediaQuery.of(context).size.width < 500;

    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
        await _loadPendingIncidents();
      },
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
            // ── Header ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMain,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                              plan != null ? 'Plan v${plan.version}' : 'No Plan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: plan != null ? AppTheme.primary : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          if (_pendingIncidents.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.amberSoft,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppTheme.amber.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '${_pendingIncidents.length} pending',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.amber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Action Buttons ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _actionInProgress ? null : _handleReset,
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _actionInProgress
                        ? null
                        : (plan == null ? _handleInitialPlan : widget.onRefresh),
                    icon: Icon(
                        plan == null
                            ? Icons.play_arrow_rounded
                            : Icons.refresh_rounded,
                        size: 18),
                    label: Text(plan == null ? 'Generate Plan' : 'Refresh Plan'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Pending Disruptions Queue ────────────────────────────
            _SectionCard(
              icon: Icons.inbox_rounded,
              iconColor: _pendingIncidents.isNotEmpty ? AppTheme.amber : AppTheme.textMuted,
              iconBg: _pendingIncidents.isNotEmpty ? AppTheme.amberSoft : AppTheme.surfaceElevated,
              title: 'Pending Disruptions',
              badge: '${_pendingIncidents.length}',
              trailing: TextButton.icon(
                onPressed: _loadPendingIncidents,
                icon: const Icon(Icons.sync_rounded, size: 14),
                label: const Text('Check', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              child: _loadingPending
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary),
                      ),
                    )
                  : _pendingIncidents.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.emerald.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  color: AppTheme.emerald, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Fleet operations on schedule. No pending disruptions.',
                                  style: TextStyle(
                                      color: AppTheme.emerald,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: _pendingIncidents
                              .map((inc) => _PendingIncidentCard(
                                    incident: inc,
                                    onConfirm: () => _handleConfirmIncident(inc),
                                    onReject: () => _handleRejectIncident(inc),
                                  ))
                              .toList(),
                        ),
            ),
            const SizedBox(height: 16),

            // ── Plan Comparison ─────────────────────────────────────
            if (_comparison != null) ...[
              _SectionCard(
                icon: Icons.compare_arrows_rounded,
                iconColor: AppTheme.primary,
                iconBg: AppTheme.primarySoft,
                title: 'Replan Diff',
                badge:
                    '#${_comparison!.parentPlanId} → #${_comparison!.planId}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _CountChip('KEPT', _comparison!.counts['KEPT'] ?? 0,
                            AppTheme.emerald, AppTheme.emeraldSoft),
                        _CountChip('MOVED', _comparison!.counts['MOVED'] ?? 0,
                            AppTheme.amber, AppTheme.amberSoft),
                        _CountChip(
                            'DONE',
                            _comparison!.counts['COMPLETED'] ?? 0,
                            AppTheme.indigo,
                            AppTheme.indigoSoft),
                        _CountChip('BROKEN', _comparison!.counts['BROKEN'] ?? 0,
                            AppTheme.rose, AppTheme.roseSoft),
                      ],
                    ),
                    if (_comparison!.changes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(color: AppTheme.border, height: 1),
                      const SizedBox(height: 10),
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
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: softBg,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: color.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: color),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${ch['order_id']}: $reason',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Network Map ─────────────────────────────────────────
            Row(
              children: [
                const Text(
                  'Route Map',
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
                    onPressed: () =>
                        setState(() => _selectedVehicleFilter = null),
                    icon: const Icon(Icons.clear_rounded, size: 13),
                    label: const Text('Show All', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: isCompact ? 280 : 360,
                child: RouteMapWidget(
                  plan: plan,
                  locations: widget.locations,
                  highlightedVehicleId: _selectedVehicleFilter,
                  activeClosures: _pendingIncidents
                      .where((i) => i.eventType == 'ROAD_CLOSURE')
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Fleet Overview ──────────────────────────────────────
            const Text(
              'Fleet Overview',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            if (plan != null)
              ...plan.vehicles.map((v) {
                final selected = _selectedVehicleFilter == v.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedVehicleFilter = selected ? null : v.id;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primarySoft : AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : (v.isFailed
                                ? AppTheme.rose.withValues(alpha: 0.4)
                                : AppTheme.border),
                        width: selected ? 1.5 : 1,
                      ),
                      boxShadow: AppTheme.shadowSm,
                    ),
                    child: Row(
                      children: [
                        // Vehicle icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: v.isFailed
                                ? AppTheme.roseSoft
                                : (selected ? AppTheme.surfaceWhite : AppTheme.surfaceElevated),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.local_shipping_rounded,
                            size: 18,
                            color: v.isFailed ? AppTheme.rose : AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    v.id,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textMain),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: v.isFailed
                                          ? AppTheme.roseSoft
                                          : AppTheme.emeraldSoft,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: v.isFailed
                                            ? AppTheme.rose.withValues(alpha: 0.3)
                                            : AppTheme.emerald.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      v.status,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: v.isFailed
                                            ? AppTheme.rose
                                            : AppTheme.emerald,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '${v.stops.length} stops',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${v.weightUtilPct.toStringAsFixed(0)}% utilized',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (v.weightUtilPct / 100).clamp(0.0, 1.0),
                                  minHeight: 5,
                                  backgroundColor: selected
                                      ? AppTheme.surfaceWhite
                                      : AppTheme.surfaceElevated,
                                  valueColor: AlwaysStoppedAnimation(
                                      v.isFailed ? AppTheme.rose : AppTheme.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 18,
                          color: selected ? AppTheme.primary : AppTheme.textDim,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Section Card ────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? badge;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.badge,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted),
                  ),
                ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─── Count Chip ──────────────────────────────────────────────────────────────
class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color softBg;
  const _CountChip(this.label, this.count, this.color, this.softBg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: softBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
          Text('$count',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ─── Pending Incident Card ───────────────────────────────────────────────────
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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasErrors
              ? AppTheme.rose.withValues(alpha: 0.35)
              : AppTheme.amber.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: incident.source == 'AI_PARSER'
                      ? AppTheme.indigoSoft
                      : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: incident.source == 'AI_PARSER'
                        ? AppTheme.indigo.withValues(alpha: 0.3)
                        : AppTheme.border,
                  ),
                ),
                child: Text(
                  incident.source == 'AI_PARSER' ? 'AI' : 'Form',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: incident.source == 'AI_PARSER'
                        ? AppTheme.indigo
                        : AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '#${incident.id} ${incident.eventType}',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Details
          if (incident.rawText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '"${incident.rawText}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary),
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (incident.vehicleId != null)
                Text('Vehicle: ${incident.vehicleId}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              if (incident.locationId != null)
                Text('Location: ${incident.locationId}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              if (incident.fromLocation != null)
                Text('${incident.fromLocation} → ${incident.toLocation}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              if (incident.incidentTime != null)
                Text('Time: ${incident.incidentTime}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
          if (hasErrors) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.roseSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.rose, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      incident.validationErrors.join("; "),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.rose,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.rose,
                    side: BorderSide(color: AppTheme.rose.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Confirm & Re-plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
