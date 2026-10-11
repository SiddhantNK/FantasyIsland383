import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class DriverScreen extends StatefulWidget {
  final PlanModel? plan;
  final List<LocationModel> locations;
  final VoidCallback onRefresh;

  const DriverScreen({
    super.key,
    required this.plan,
    required this.locations,
    required this.onRefresh,
  });

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  late String _selectedVehicleId;
  List<DisruptionModel> _recentReports = [];
  bool _loadingReports = false;

  @override
  void initState() {
    super.initState();
    // Default to the driver's assigned vehicle or V01
    _selectedVehicleId = AuthService.currentUser?.vehicleId ?? 'V01';
    _loadRecentReports();
  }

  Future<void> _loadRecentReports() async {
    setState(() => _loadingReports = true);
    try {
      final incidents = await ApiService.getIncidents();
      if (mounted) {
        setState(() {
          _recentReports = incidents.reversed.take(5).toList();
          _loadingReports = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  VehicleModel? get _currentVehicle {
    if (widget.plan == null) return null;
    return widget.plan!.vehicles.firstWhere(
      (v) => v.id == _selectedVehicleId,
      orElse: () => widget.plan!.vehicles.first,
    );
  }

  void _openReportDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IncidentReportSheet(
        defaultVehicleId: _selectedVehicleId,
        locations: widget.locations,
        onSuccess: () {
          _loadRecentReports();
          widget.onRefresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _currentVehicle;
    final stops = vehicle?.stops ?? [];
    final isCompact = MediaQuery.of(context).size.width < 500;

    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
        await _loadRecentReports();
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
            const Text(
              'My Route',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Active shift route & incident reporting',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),

            // ── Vehicle Selector ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: (widget.plan?.vehicles.map((v) => v.id).toList() ?? ['V01', 'V02', 'V03'])
                    .map((vId) {
                  final selected = _selectedVehicleId == vId;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedVehicleId = vId),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.surfaceWhite : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: selected ? AppTheme.shadowSm : null,
                          border: Border.all(
                            color: selected ? AppTheme.border : Colors.transparent,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            vId,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected ? AppTheme.primary : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Vehicle Status Card ─────────────────────────────────
            if (vehicle != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: vehicle.isFailed
                        ? AppTheme.rose.withValues(alpha: 0.4)
                        : AppTheme.border,
                  ),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: vehicle.isFailed ? AppTheme.roseSoft : AppTheme.emeraldSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: vehicle.isFailed
                                  ? AppTheme.rose.withValues(alpha: 0.3)
                                  : AppTheme.emerald.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                vehicle.isFailed
                                    ? Icons.error_outline_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 14,
                                color: vehicle.isFailed ? AppTheme.rose : AppTheme.emerald,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                vehicle.isFailed
                                    ? 'FAILED AT ${vehicle.failedAt}'
                                    : 'ACTIVE',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: vehicle.isFailed ? AppTheme.rose : AppTheme.emerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${stops.length} stops',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Capacity bars
                    _CapacityBar(
                      label: 'Weight',
                      value:
                          '${vehicle.pendingWeightKg.toStringAsFixed(0)} / ${vehicle.weightCapKg.toStringAsFixed(0)} kg',
                      pct: vehicle.weightUtilPct,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 10),
                    _CapacityBar(
                      label: 'Volume',
                      value:
                          '${vehicle.pendingVolumeM3.toStringAsFixed(1)} / ${vehicle.volumeCapM3.toStringAsFixed(1)} m³',
                      pct: vehicle.volumeUtilPct,
                      color: AppTheme.indigo,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.route_outlined, size: 32, color: AppTheme.textDim),
                      const SizedBox(height: 10),
                      const Text(
                        'No active plan yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ask your dispatcher to generate the initial plan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // ── Report Disruption FAB-style button ──────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openReportDialog,
                icon: const Icon(Icons.warning_amber_rounded, size: 20),
                label: const Text('Report Disruption'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Route Stops ─────────────────────────────────────────
            Row(
              children: [
                const Text(
                  'Route Manifest',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMain,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                if (stops.isNotEmpty)
                  Text(
                    '${stops.length} stops assigned',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (stops.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Center(
                  child: Text(
                    'No stops assigned to this vehicle.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stops.length,
                itemBuilder: (context, index) {
                  return _StopCard(stop: stops[index], index: index + 1);
                },
              ),

            const SizedBox(height: 24),

            // ── Recent Incident Reports ─────────────────────────────
            Row(
              children: [
                const Text(
                  'Recent Reports',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMain,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadRecentReports,
                  icon: const Icon(Icons.sync_rounded, size: 14),
                  label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingReports)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              )
            else if (_recentReports.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: AppTheme.emerald),
                    SizedBox(width: 10),
                    Text(
                      'No incidents submitted yet.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ..._recentReports.map((inc) => _IncidentStatusTile(incident: inc)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Capacity Bar ────────────────────────────────────────────────────────────
class _CapacityBar extends StatelessWidget {
  final String label;
  final String value;
  final double pct;
  final Color color;

  const _CapacityBar({
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
            Text(value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppTheme.surfaceElevated,
            valueColor: AlwaysStoppedAnimation<Color>(pct > 90 ? AppTheme.rose : color),
          ),
        ),
      ],
    );
  }
}

// ─── Stop Card ───────────────────────────────────────────────────────────────
class _StopCard extends StatelessWidget {
  final StopModel stop;
  final int index;

  const _StopCard({required this.stop, required this.index});

  Color _badgeColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return AppTheme.emerald;
      case 'MOVED':
        return AppTheme.amber;
      case 'BROKEN':
        return AppTheme.rose;
      default:
        return AppTheme.primary;
    }
  }

  Color _badgeSoftColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return AppTheme.emeraldSoft;
      case 'MOVED':
        return AppTheme.amberSoft;
      case 'BROKEN':
        return AppTheme.roseSoft;
      default:
        return AppTheme.primarySoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor(stop.status);
    final softColor = _badgeSoftColor(stop.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          // Index circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: softColor,
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ),
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
                        stop.locationId,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: softColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        stop.status,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Order ${stop.orderId}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 12, color: AppTheme.textDim),
                    const SizedBox(width: 4),
                    Text(
                      '${stop.arrival ?? "--:--"} → ${stop.departure ?? "--:--"}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                    if (stop.window != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Window: ${stop.window}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textDim),
                      ),
                    ],
                  ],
                ),
                if (stop.reason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    stop.reason!,
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: color),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Incident Status Tile ────────────────────────────────────────────────────
class _IncidentStatusTile extends StatelessWidget {
  final DisruptionModel incident;
  const _IncidentStatusTile({required this.incident});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color softColor;
    switch (incident.status) {
      case 'CONFIRMED':
        color = AppTheme.emerald;
        softColor = AppTheme.emeraldSoft;
        break;
      case 'REJECTED':
        color = AppTheme.rose;
        softColor = AppTheme.roseSoft;
        break;
      default:
        color = AppTheme.amber;
        softColor = AppTheme.amberSoft;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          // Source badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              color: incident.source == 'AI_PARSER' ? AppTheme.indigoSoft : AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(5),
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
                color: incident.source == 'AI_PARSER' ? AppTheme.indigo : AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${incident.eventType} #${incident.id}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                ),
                if (incident.rawText != null)
                  Text(
                    incident.rawText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: softColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              incident.status,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Incident Report Bottom Sheet ────────────────────────────────────────────
class _IncidentReportSheet extends StatefulWidget {
  final String defaultVehicleId;
  final List<LocationModel> locations;
  final VoidCallback onSuccess;

  const _IncidentReportSheet({
    required this.defaultVehicleId,
    required this.locations,
    required this.onSuccess,
  });

  @override
  State<_IncidentReportSheet> createState() => _IncidentReportSheetState();
}

class _IncidentReportSheetState extends State<_IncidentReportSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // AI Tab state
  final TextEditingController _promptController = TextEditingController();
  bool _isParsing = false;
  Map<String, dynamic>? _parsedPreview;
  String? _parseError;

  // Form Tab state
  String _eventType = 'VEHICLE_FAILURE';
  late String _vehicleId;
  String _locationId = 'C01';
  String _fromLoc = 'C01';
  String _toLoc = 'C02';
  final TextEditingController _incidentTimeController =
      TextEditingController(text: '11:30');
  final TextEditingController _endTimeController =
      TextEditingController(text: '13:00');
  final TextEditingController _weightController =
      TextEditingController(text: '50');
  final TextEditingController _volumeController =
      TextEditingController(text: '0.4');
  final TextEditingController _latestTimeController =
      TextEditingController(text: '14:00');
  bool _submitting = false;

  final List<String> _samplePrompts = [
    "My truck V02 has broken down near Customer C04 at 11:30 AM. Cannot continue.",
    "Road closed between C01 and C02 starting at 09:00 until 12:00 due to tree fall.",
    "Urgent order at C05 at 10:15, 50kg, 0.4m3, latest delivery 14:00.",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _vehicleId = widget.defaultVehicleId;
  }

  Future<void> _handleParse() async {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isParsing = true;
      _parseError = null;
      _parsedPreview = null;
    });

    try {
      final res = await ApiService.parseIncident(text);
      setState(() {
        final parsedData = (res['parsed'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(res['parsed'])
            : res;
        if (res['clarification'] != null) {
          parsedData['clarification'] = res['clarification'];
        }
        _parsedPreview = parsedData;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _parseError = e.toString().replaceAll('Exception: ', '');
        _isParsing = false;
      });
    }
  }

  Future<void> _submitAiParsed() async {
    if (_parsedPreview == null) return;
    if (_parsedPreview!['event_type'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_parsedPreview!['clarification'] ??
              'Could not identify incident type. Please try again or use the form tab.'),
          backgroundColor: AppTheme.rose,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final payload = Map<String, dynamic>.from(_parsedPreview!);
      payload['source'] = 'AI_PARSER';
      payload['raw_text'] = _promptController.text.trim();

      await ApiService.submitIncident(payload);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.emerald,
            content: Text('Incident reported via AI! Pending dispatcher confirmation.'),
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _submitForm() async {
    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'event_type': _eventType,
        'source': 'FORM',
        'incident_time': _incidentTimeController.text.trim(),
      };

      if (_eventType == 'VEHICLE_FAILURE') {
        payload['vehicle_id'] = _vehicleId;
        payload['location_id'] = _locationId;
      } else if (_eventType == 'ROAD_CLOSURE') {
        payload['from_location'] = _fromLoc;
        payload['to_location'] = _toLoc;
        if (_endTimeController.text.isNotEmpty) {
          payload['end_time'] = _endTimeController.text.trim();
        }
      } else if (_eventType == 'URGENT_ORDER') {
        payload['location_id'] = _locationId;
        payload['order'] = {
          'location_id': _locationId,
          'weight_kg': double.tryParse(_weightController.text) ?? 20.0,
          'volume_m3': double.tryParse(_volumeController.text) ?? 0.2,
          'earliest': _incidentTimeController.text.trim(),
          'latest': _latestTimeController.text.trim(),
        };
      }

      await ApiService.submitIncident(payload);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.emerald,
            content: Text('Incident submitted to dispatcher!'),
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.amberSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.amber, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Disruption',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMain,
                        ),
                      ),
                      Text(
                        'Use AI or fill the structured form',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceElevated,
                  ),
                ),
              ],
            ),
          ),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(8),
                boxShadow: AppTheme.shadowSm,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerHeight: 0,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 15),
                      SizedBox(width: 6),
                      Text('AI Parser'),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt_rounded, size: 15),
                      SizedBox(width: 6),
                      Text('Form'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAiTab(),
                _buildFormTab(),
              ],
            ),
          ),
          SizedBox(height: bottomInset > 0 ? 0 : 8),
        ],
      ),
    );
  }

  Widget _buildAiTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Describe what happened',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMain),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g., My truck V02 broke down near C04 at 11:30…',
            ),
          ),
          const SizedBox(height: 12),
          // Quick sample chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _samplePrompts.map((p) {
              return GestureDetector(
                onTap: () => setState(() => _promptController.text = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    p.length > 40 ? '${p.substring(0, 40)}…' : p,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isParsing ? null : _handleParse,
              icon: _isParsing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 17),
              label:
                  Text(_isParsing ? 'Analyzing…' : 'Analyze with AI'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_parseError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.roseSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.rose),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_parseError!,
                        style: const TextStyle(color: AppTheme.rose, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          ],
          if (_parsedPreview != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.emeraldSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 16, color: AppTheme.emerald),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Extraction',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.emerald,
                            fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PreviewRow(
                      'Event', _parsedPreview!['event_type']?.toString() ?? 'UNKNOWN'),
                  if (_parsedPreview!['vehicle_id'] != null)
                    _PreviewRow(
                        'Vehicle', _parsedPreview!['vehicle_id'].toString()),
                  if (_parsedPreview!['location_id'] != null)
                    _PreviewRow(
                        'Location', _parsedPreview!['location_id'].toString()),
                  if (_parsedPreview!['incident_time'] != null)
                    _PreviewRow(
                        'Time', _parsedPreview!['incident_time'].toString()),
                  if (_parsedPreview!['clarification'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.amberSoft,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _parsedPreview!['clarification'],
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.amber,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submitAiParsed,
                      icon: const Icon(Icons.send_rounded, size: 16),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      label: Text(
                          _submitting ? 'Sending…' : 'Send to Dispatcher'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormTab() {
    final locIds = widget.locations.map((l) => l.id).toList();
    if (!locIds.contains(_locationId) && locIds.isNotEmpty) _locationId = locIds.first;
    if (!locIds.contains(_fromLoc) && locIds.isNotEmpty) _fromLoc = locIds.first;
    if (!locIds.contains(_toLoc) && locIds.isNotEmpty) {
      _toLoc = locIds.length > 1 ? locIds[1] : locIds.first;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _eventType,
            decoration: const InputDecoration(labelText: 'Disruption Type'),
            items: const [
              DropdownMenuItem(
                  value: 'VEHICLE_FAILURE', child: Text('Vehicle Breakdown')),
              DropdownMenuItem(
                  value: 'ROAD_CLOSURE', child: Text('Road Closure')),
              DropdownMenuItem(
                  value: 'URGENT_ORDER', child: Text('Urgent Order')),
            ],
            onChanged: (v) => setState(() => _eventType = v!),
          ),
          const SizedBox(height: 14),
          if (_eventType == 'VEHICLE_FAILURE') ...[
            DropdownButtonFormField<String>(
              value: _vehicleId,
              decoration: const InputDecoration(labelText: 'Affected Vehicle'),
              items: ['V01', 'V02', 'V03']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => _vehicleId = v!),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _locationId,
              decoration: const InputDecoration(labelText: 'Breakdown Location'),
              items: locIds
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _locationId = v!),
            ),
          ] else if (_eventType == 'ROAD_CLOSURE') ...[
            DropdownButtonFormField<String>(
              value: _fromLoc,
              decoration: const InputDecoration(labelText: 'From Location'),
              items: locIds
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _fromLoc = v!),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _toLoc,
              decoration: const InputDecoration(labelText: 'To Location'),
              items: locIds
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _toLoc = v!),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _endTimeController,
              decoration: const InputDecoration(labelText: 'Closure End Time (HH:MM)'),
            ),
          ] else if (_eventType == 'URGENT_ORDER') ...[
            DropdownButtonFormField<String>(
              value: _locationId,
              decoration: const InputDecoration(labelText: 'Delivery Destination'),
              items: locIds
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _locationId = v!),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _volumeController,
                    decoration: const InputDecoration(labelText: 'Volume (m³)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _latestTimeController,
              decoration:
                  const InputDecoration(labelText: 'Latest Delivery (HH:MM)'),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _incidentTimeController,
            decoration: const InputDecoration(labelText: 'Incident Time (HH:MM)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submitForm,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(_submitting ? 'Submitting…' : 'Submit to Dispatcher'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Preview Row ─────────────────────────────────────────────────────────────
class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textMain, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
