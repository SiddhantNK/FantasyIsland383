import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DriverScreen extends StatefulWidget {
  final PlanModel? plan;
  final List<LocationModel> locations;
  final VoidCallback onRefresh;
  final String? lockedVehicleId;

  const DriverScreen({
    super.key,
    required this.plan,
    required this.locations,
    required this.onRefresh,
    this.lockedVehicleId,
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
    _selectedVehicleId = widget.lockedVehicleId ?? 'V01';
    _loadRecentReports();
  }

  @override
  void didUpdateWidget(covariant DriverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lockedVehicleId != null && widget.lockedVehicleId != _selectedVehicleId) {
      _selectedVehicleId = widget.lockedVehicleId!;
    }
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Vehicle Selector
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver Dispatch View',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active Shift Route & Live Incident Reporting',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const Spacer(),
              // Vehicle Selector Pills (dispatchers can switch; drivers stay on their truck)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: ['V01', 'V02', 'V03'].map((vId) {
                    final selected = _selectedVehicleId == vId;
                    final locked = widget.lockedVehicleId != null;
                    return GestureDetector(
                      onTap: locked ? null : () => setState(() => _selectedVehicleId = vId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          vId,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : (locked ? AppTheme.textDim : AppTheme.textMuted),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Vehicle Status Card
          if (vehicle != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: vehicle.isFailed ? AppTheme.rose.withOpacity(0.5) : AppTheme.border,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: vehicle.isFailed
                              ? AppTheme.rose.withOpacity(0.2)
                              : AppTheme.emerald.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: vehicle.isFailed ? AppTheme.rose : AppTheme.emerald,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              vehicle.isFailed ? Icons.error_outline : Icons.check_circle_outline,
                              size: 14,
                              color: vehicle.isFailed ? AppTheme.rose : AppTheme.emerald,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              vehicle.isFailed ? 'FAILED AT ${vehicle.failedAt}' : 'ACTIVE & RUNNING',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: vehicle.isFailed ? AppTheme.rose : AppTheme.emerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _openReportDialog,
                        icon: const Icon(Icons.warning_amber_rounded, size: 18),
                        label: const Text('Report Disruption'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.amber,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Utilization Bars
                  Row(
                    children: [
                      Expanded(
                        child: _utilizationBar(
                          'Weight Capacity',
                          '${vehicle.pendingWeightKg.toStringAsFixed(0)} / ${vehicle.weightCapKg.toStringAsFixed(0)} kg',
                          vehicle.weightUtilPct,
                          AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _utilizationBar(
                          'Volume Capacity',
                          '${vehicle.pendingVolumeM3.toStringAsFixed(1)} / ${vehicle.volumeCapM3.toStringAsFixed(1)} m³',
                          vehicle.volumeUtilPct,
                          AppTheme.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Center(
                child: Text('No active plan generated yet. Generate initial plan in Dispatcher view.'),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Route Stops Timeline
          const Text(
            'Assigned Route Manifest',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
          ),
          const SizedBox(height: 12),

          if (stops.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Center(
                child: Text('No stops assigned to this vehicle in current plan.',
                    style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stops.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final stop = stops[index];
                return _StopCard(stop: stop, index: index + 1);
              },
            ),

          const SizedBox(height: 28),

          // Recent Driver Reports Status
          Row(
            children: [
              const Text(
                'Recent Incident Reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: AppTheme.textMuted),
                onPressed: _loadRecentReports,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingReports)
            const Center(child: CircularProgressIndicator())
          else if (_recentReports.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text('No incidents submitted recently.',
                  style: TextStyle(color: AppTheme.textMuted)),
            )
          else
            ..._recentReports.map((inc) => _IncidentStatusTile(incident: inc)),
        ],
      ),
    );
  }

  Widget _utilizationBar(String title, String subtitle, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppTheme.surfaceElevated,
            valueColor: AlwaysStoppedAnimation<Color>(pct > 90 ? AppTheme.rose : color),
          ),
        ),
      ],
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor(stop.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Sequence index
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Center(
              child: Text(
                '#$index',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMain),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Stop: ${stop.locationId}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${stop.orderId})',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(0.8)),
                      ),
                      child: Text(
                        stop.status,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: AppTheme.textDim),
                    const SizedBox(width: 4),
                    Text(
                      'Arrival: ${stop.arrival ?? "--:--"} | Departure: ${stop.departure ?? "--:--"}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    if (stop.window != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.timer_outlined, size: 13, color: AppTheme.textDim),
                      const SizedBox(width: 4),
                      Text(
                        'Window: ${stop.window}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ],
                ),
                if (stop.reason != null) ...[
                  const SizedBox(height: 6),
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

class _IncidentStatusTile extends StatelessWidget {
  final DisruptionModel incident;
  const _IncidentStatusTile({required this.incident});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (incident.status) {
      case 'CONFIRMED':
        color = AppTheme.emerald;
        break;
      case 'REJECTED':
        color = AppTheme.rose;
        break;
      default:
        color = AppTheme.amber;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: incident.source == 'AI_PARSER' ? AppTheme.indigo.withOpacity(0.2) : AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              incident.source,
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
                  '${incident.eventType} (ID #${incident.id})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                ),
                if (incident.rawText != null)
                  Text(
                    incident.rawText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color),
            ),
            child: Text(
              incident.status,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _IncidentReportSheetState extends State<_IncidentReportSheet> with SingleTickerProviderStateMixin {
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
  final TextEditingController _incidentTimeController = TextEditingController(text: '11:30');
  final TextEditingController _endTimeController = TextEditingController(text: '13:00');
  final TextEditingController _weightController = TextEditingController(text: '50');
  final TextEditingController _volumeController = TextEditingController(text: '0.4');
  final TextEditingController _latestTimeController = TextEditingController(text: '14:00');
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
        _parsedPreview = res;
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
    setState(() => _submitting = true);
    try {
      final payload = Map<String, dynamic>.from(_parsedPreview!);
      payload['source'] = 'AI_PARSER';
      payload['raw_text'] = _promptController.text.trim();

      await ApiService.submitIncident(payload);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident reported via AI! Pending dispatcher confirmation.')),
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
          const SnackBar(content: Text('Structured incident submitted to dispatcher!')),
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Tab bar
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.textMain,
            unselectedLabelColor: AppTheme.textMuted,
            tabs: const [
              Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'AI Natural Language'),
              Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Structured Form'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAiTab(),
                _buildFormTab(),
              ],
            ),
          ),
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
            'Describe the disruption in plain words:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMain),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g., My truck V02 has broken down near C04 at 11:30 AM...',
            ),
          ),
          const SizedBox(height: 10),
          // Quick sample chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _samplePrompts.map((p) {
              return ActionChip(
                backgroundColor: AppTheme.surfaceElevated,
                label: Text(
                  p.length > 38 ? '${p.substring(0, 38)}...' : p,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                onPressed: () => setState(() => _promptController.text = p),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isParsing ? null : _handleParse,
              icon: _isParsing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_isParsing ? 'Parsing with Gemini...' : 'Analyze with AI Parser'),
            ),
          ),
          if (_parseError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.rose.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.rose),
              ),
              child: Text(_parseError!, style: const TextStyle(color: AppTheme.rose, fontSize: 13)),
            ),
          ],
          if (_parsedPreview != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Extraction Preview:',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.emeraldLight)),
                  const SizedBox(height: 8),
                  Text('Event: ${_parsedPreview!['event_type'] ?? "UNKNOWN"}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMain)),
                  if (_parsedPreview!['vehicle_id'] != null)
                    Text('Vehicle: ${_parsedPreview!['vehicle_id']}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textMain)),
                  if (_parsedPreview!['location_id'] != null)
                    Text('Location: ${_parsedPreview!['location_id']}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textMain)),
                  if (_parsedPreview!['incident_time'] != null)
                    Text('Time: ${_parsedPreview!['incident_time']}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textMain)),
                  if (_parsedPreview!['clarification'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _parsedPreview!['clarification'],
                        style: const TextStyle(fontSize: 12, color: AppTheme.amberLight),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitAiParsed,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                      child: Text(_submitting ? 'Submitting...' : 'Confirm & Send to Dispatcher'),
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
    if (!locIds.contains(_toLoc) && locIds.isNotEmpty) _toLoc = locIds.length > 1 ? locIds[1] : locIds.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _eventType,
            decoration: const InputDecoration(labelText: 'Disruption Event Type'),
            dropdownColor: AppTheme.surfaceDark,
            items: const [
              DropdownMenuItem(value: 'VEHICLE_FAILURE', child: Text('Vehicle Breakdown (VEHICLE_FAILURE)')),
              DropdownMenuItem(value: 'ROAD_CLOSURE', child: Text('Road Closure (ROAD_CLOSURE)')),
              DropdownMenuItem(value: 'URGENT_ORDER', child: Text('Urgent Order Request (URGENT_ORDER)')),
            ],
            onChanged: (v) => setState(() => _eventType = v!),
          ),
          const SizedBox(height: 14),
          if (_eventType == 'VEHICLE_FAILURE') ...[
            DropdownButtonFormField<String>(
              value: _vehicleId,
              decoration: const InputDecoration(labelText: 'Affected Vehicle'),
              dropdownColor: AppTheme.surfaceDark,
              items: ['V01', 'V02', 'V03']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => _vehicleId = v!),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _locationId,
              decoration: const InputDecoration(labelText: 'Breakdown Location'),
              dropdownColor: AppTheme.surfaceDark,
              items: locIds.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) => setState(() => _locationId = v!),
            ),
          ] else if (_eventType == 'ROAD_CLOSURE') ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _fromLoc,
                    decoration: const InputDecoration(labelText: 'From Junction/Location'),
                    dropdownColor: AppTheme.surfaceDark,
                    items: locIds.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _fromLoc = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _toLoc,
                    decoration: const InputDecoration(labelText: 'To Junction/Location'),
                    dropdownColor: AppTheme.surfaceDark,
                    items: locIds.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _toLoc = v!),
                  ),
                ),
              ],
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
              dropdownColor: AppTheme.surfaceDark,
              items: locIds.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
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
              decoration: const InputDecoration(labelText: 'Latest Delivery Deadline (HH:MM)'),
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
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitForm,
              child: Text(_submitting ? 'Submitting...' : 'Submit to Dispatcher'),
            ),
          ),
        ],
      ),
    );
  }
}
