import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class RouteMapWidget extends StatelessWidget {
  final PlanModel? plan;
  final List<LocationModel> locations;
  final String? highlightedVehicleId;
  final List<DisruptionModel> activeClosures;

  const RouteMapWidget({
    super.key,
    required this.plan,
    required this.locations,
    this.highlightedVehicleId,
    this.activeClosures = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Grid background
            CustomPaint(
              size: Size.infinite,
              painter: GridPainter(),
            ),
            // Routes & nodes painter
            CustomPaint(
              size: Size.infinite,
              painter: NetworkPainter(
                plan: plan,
                locations: locations,
                highlightedVehicleId: highlightedVehicleId,
                activeClosures: activeClosures,
              ),
            ),
            // Map Legend overlay
            Positioned(
              left: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendItem(AppTheme.primary, 'V01'),
                    const SizedBox(width: 12),
                    _legendItem(AppTheme.emerald, 'V02'),
                    const SizedBox(width: 12),
                    _legendItem(AppTheme.purple, 'V03'),
                    const SizedBox(width: 12),
                    _legendItem(AppTheme.rose, 'Closure / Alert'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NetworkPainter extends CustomPainter {
  final PlanModel? plan;
  final List<LocationModel> locations;
  final String? highlightedVehicleId;
  final List<DisruptionModel> activeClosures;

  static const Map<String, List<double>> fallbackCoords = {
    'DEPOT': [0.0, 0.0],
    'C01': [4.0, 3.0],
    'C02': [7.0, 1.0],
    'C03': [9.0, 5.0],
    'C04': [3.0, 8.0],
    'C05': [-3.0, 6.0],
    'C06': [-6.0, 2.0],
    'C07': [-4.0, -4.0],
    'C08': [2.0, -6.0],
    'C09': [8.0, -3.0],
    'C10': [-8.0, -6.0],
  };

  NetworkPainter({
    required this.plan,
    required this.locations,
    this.highlightedVehicleId,
    required this.activeClosures,
  });

  Color _vehicleColor(String vId) {
    switch (vId) {
      case 'V01':
        return AppTheme.primary;
      case 'V02':
        return AppTheme.emerald;
      case 'V03':
        return AppTheme.purple;
      default:
        return AppTheme.amber;
    }
  }

  Offset _toScreen(double lat, double lng, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = (size.width < size.height ? size.width : size.height) / 24.0;

    return Offset(
      cx + (lng * scale),
      cy - (lat * scale),
    );
  }

  Offset? _getOffset(Map<String, LocationModel> locMap, String id, Size size) {
    final loc = locMap[id];
    double? lat = loc?.lat;
    double? lng = loc?.lng;
    if (lat == null || lng == null) {
      final fb = fallbackCoords[id];
      if (fb != null) {
        lat = fb[0];
        lng = fb[1];
      }
    }
    if (lat == null || lng == null) return null;
    return _toScreen(lat, lng, size);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final locMap = {for (var l in locations) l.id: l};

    // Draw active road closures first (dashed/bold red line)
    for (var c in activeClosures) {
      if (c.fromLocation != null && c.toLocation != null) {
        final p1 = _getOffset(locMap, c.fromLocation!, size);
        final p2 = _getOffset(locMap, c.toLocation!, size);
        if (p1 != null && p2 != null) {
          final paint = Paint()
            ..color = AppTheme.rose.withValues(alpha: 0.85)
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(p1, p2, paint);
        }
      }
    }

    // Draw vehicle routes
    if (plan != null) {
      final depotOffset = _getOffset(locMap, 'DEPOT', size) ?? Offset(size.width / 2, size.height / 2);

      for (var v in plan!.vehicles) {
        if (highlightedVehicleId != null && v.id != highlightedVehicleId) {
          continue;
        }

        final color = _vehicleColor(v.id);
        final linePaint = Paint()
          ..color = v.isFailed ? AppTheme.textDim.withValues(alpha: 0.3) : color.withValues(alpha: 0.85)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round;

        final path = Path();
        path.moveTo(depotOffset.dx, depotOffset.dy);

        final sortedStops = List<StopModel>.from(v.stops)..sort((a, b) => a.seq.compareTo(b.seq));
        for (var stop in sortedStops) {
          final pt = _getOffset(locMap, stop.locationId, size);
          if (pt != null) {
            path.lineTo(pt.dx, pt.dy);
          }
        }

        canvas.drawPath(path, linePaint);
      }
    }

    // Determine all node IDs to draw (locations or fallback keys)
    final nodeIds = locations.isNotEmpty ? locations.map((l) => l.id).toSet() : fallbackCoords.keys.toSet();

    for (var id in nodeIds) {
      final pt = _getOffset(locMap, id, size);
      if (pt == null) continue;
      final isDepot = id == 'DEPOT';

      final nodePaint = Paint()
        ..color = isDepot ? AppTheme.amber : AppTheme.surfaceDark
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = isDepot ? Colors.white : AppTheme.borderLight
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      // Glow effect for depot
      if (isDepot) {
        final glowPaint = Paint()
          ..color = AppTheme.amber.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(pt, 16, glowPaint);
      }

      final radius = isDepot ? 10.0 : 7.0;
      canvas.drawCircle(pt, radius, nodePaint);
      canvas.drawCircle(pt, radius, borderPaint);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: id,
          style: TextStyle(
            color: isDepot ? AppTheme.amberLight : AppTheme.textMuted,
            fontSize: isDepot ? 11 : 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy + radius + 4));
    }
  }

  @override
  bool shouldRepaint(covariant NetworkPainter oldDelegate) => true;
}
