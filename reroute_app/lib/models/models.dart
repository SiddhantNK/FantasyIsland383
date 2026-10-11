// Data models corresponding to ReRoute backend structures

class VehicleModel {
  final String id;
  final double weightCapKg;
  final double volumeCapM3;
  final String status; // ACTIVE | FAILED
  final String? failedAt;
  final double pendingWeightKg;
  final double pendingVolumeM3;
  final double weightUtilPct;
  final double volumeUtilPct;
  final List<StopModel> stops;

  VehicleModel({
    required this.id,
    required this.weightCapKg,
    required this.volumeCapM3,
    required this.status,
    this.failedAt,
    this.pendingWeightKg = 0,
    this.pendingVolumeM3 = 0,
    this.weightUtilPct = 0,
    this.volumeUtilPct = 0,
    this.stops = const [],
  });

  bool get isFailed => status == 'FAILED';

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] ?? '',
      weightCapKg: (json['weight_cap_kg'] as num?)?.toDouble() ?? 0.0,
      volumeCapM3: (json['volume_cap_m3'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'ACTIVE',
      failedAt: json['failed_at'],
      pendingWeightKg: (json['pending_weight_kg'] as num?)?.toDouble() ?? 0.0,
      pendingVolumeM3: (json['pending_volume_m3'] as num?)?.toDouble() ?? 0.0,
      weightUtilPct: (json['weight_util_pct'] as num?)?.toDouble() ?? 0.0,
      volumeUtilPct: (json['volume_util_pct'] as num?)?.toDouble() ?? 0.0,
      stops: (json['stops'] as List<dynamic>?)
              ?.map((s) => StopModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class LocationModel {
  final String id;
  final String name;
  final String type; // DEPOT | CUSTOMER | JUNCTION
  final double? lat;
  final double? lng;

  LocationModel({
    required this.id,
    required this.name,
    required this.type,
    this.lat,
    this.lng,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'CUSTOMER',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

class OrderModel {
  final String id;
  final String locationId;
  final double weightKg;
  final double volumeM3;
  final String earliest;
  final String latest;
  final int serviceMin;
  final int priority;
  final String status; // PENDING | ASSIGNED | COMPLETED | UNASSIGNED

  OrderModel({
    required this.id,
    required this.locationId,
    required this.weightKg,
    required this.volumeM3,
    required this.earliest,
    required this.latest,
    this.serviceMin = 10,
    this.priority = 1,
    required this.status,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      locationId: json['location_id'] ?? '',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
      volumeM3: (json['volume_m3'] as num?)?.toDouble() ?? 0.0,
      earliest: json['earliest'] ?? '',
      latest: json['latest'] ?? '',
      serviceMin: json['service_min'] ?? 10,
      priority: json['priority'] ?? 1,
      status: json['status'] ?? 'PENDING',
    );
  }
}

class StopModel {
  final String? vehicleId;
  final String orderId;
  final int seq;
  final String locationId;
  final String? arrival;
  final int waitMin;
  final String? departure;
  final String status; // PLANNED | COMPLETED | KEPT | MOVED | BROKEN
  final String? reason;
  final double? weightKg;
  final double? volumeM3;
  final String? window;

  StopModel({
    this.vehicleId,
    required this.orderId,
    required this.seq,
    required this.locationId,
    this.arrival,
    this.waitMin = 0,
    this.departure,
    required this.status,
    this.reason,
    this.weightKg,
    this.volumeM3,
    this.window,
  });

  bool get isUnassigned => vehicleId == null;

  factory StopModel.fromJson(Map<String, dynamic> json) {
    return StopModel(
      vehicleId: json['vehicle_id'],
      orderId: json['order_id'] ?? '',
      seq: json['seq'] ?? 0,
      locationId: json['location_id'] ?? '',
      arrival: json['arrival'],
      waitMin: json['wait_min'] ?? 0,
      departure: json['departure'],
      status: json['status'] ?? 'PLANNED',
      reason: json['reason'],
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      volumeM3: (json['volume_m3'] as num?)?.toDouble(),
      window: json['window'],
    );
  }
}

class PlanModel {
  final int? id;
  final int version;
  final int? parentPlanId;
  final int? disruptionId;
  final bool feasible;
  final List<VehicleModel> vehicles;
  final List<StopModel> unassigned;

  PlanModel({
    this.id,
    required this.version,
    this.parentPlanId,
    this.disruptionId,
    required this.feasible,
    this.vehicles = const [],
    this.unassigned = const [],
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'],
      version: json['version'] ?? 1,
      parentPlanId: json['parent_plan_id'],
      disruptionId: json['disruption_id'],
      feasible: json['feasible'] ?? true,
      vehicles: (json['vehicles'] as List<dynamic>?)
              ?.map((v) => VehicleModel.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      unassigned: (json['unassigned'] as List<dynamic>?)
              ?.map((s) => StopModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DisruptionModel {
  final int id;
  final String source; // FORM | AI_PARSER
  final String? rawText;
  final String eventType; // VEHICLE_FAILURE | ROAD_CLOSURE | URGENT_ORDER
  final String? vehicleId;
  final String? locationId;
  final String? fromLocation;
  final String? toLocation;
  final String? incidentTime;
  final String? endTime;
  final Map<String, dynamic>? details;
  final List<String> validationErrors;
  final String status; // PENDING | CONFIRMED | REJECTED
  final String? createdAt;

  DisruptionModel({
    required this.id,
    required this.source,
    this.rawText,
    required this.eventType,
    this.vehicleId,
    this.locationId,
    this.fromLocation,
    this.toLocation,
    this.incidentTime,
    this.endTime,
    this.details,
    this.validationErrors = const [],
    required this.status,
    this.createdAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isRejected => status == 'REJECTED';

  factory DisruptionModel.fromJson(Map<String, dynamic> json) {
    return DisruptionModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      source: json['source'] ?? 'FORM',
      rawText: json['raw_text'],
      eventType: json['event_type'] ?? '',
      vehicleId: json['vehicle_id'],
      locationId: json['location_id'],
      fromLocation: json['from_location'],
      toLocation: json['to_location'],
      incidentTime: json['incident_time'],
      endTime: json['end_time'],
      details: json['details'] as Map<String, dynamic>?,
      validationErrors: (json['validation_errors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] ?? 'PENDING',
      createdAt: json['created_at'],
    );
  }
}

class PlanComparisonModel {
  final int planId;
  final int parentPlanId;
  final Map<String, int> counts; // KEPT, MOVED, COMPLETED, BROKEN
  final List<Map<String, dynamic>> changes;

  PlanComparisonModel({
    required this.planId,
    required this.parentPlanId,
    required this.counts,
    required this.changes,
  });

  factory PlanComparisonModel.fromJson(Map<String, dynamic> json) {
    return PlanComparisonModel(
      planId: json['plan_id'] ?? 0,
      parentPlanId: json['parent_plan_id'] ?? 0,
      counts: (json['counts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
      changes: (json['changes'] as List<dynamic>?)
              ?.map((c) => c as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }
}

class HistoryModel {
  final int id;
  final int? oldPlanId;
  final int? newPlanId;
  final int? disruptionId;
  final String summary;
  final String createdAt;

  HistoryModel({
    required this.id,
    this.oldPlanId,
    this.newPlanId,
    this.disruptionId,
    required this.summary,
    required this.createdAt,
  });

  factory HistoryModel.fromJson(Map<String, dynamic> json) {
    return HistoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      oldPlanId: json['old_plan_id'],
      newPlanId: json['new_plan_id'],
      disruptionId: json['disruption_id'],
      summary: json['summary'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
