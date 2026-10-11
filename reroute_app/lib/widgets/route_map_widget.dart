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
                  color: AppTheme.surfaceDark.withOpacity(0.9),
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
                    _legendItem(AppTheme.rose, 'Closure / Broken'),
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
      ..color = AppTheme.border.withOpacity(0.25)
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
    // Coordinate mapping: lat roughly -10 to +10, lng roughly -10 to +10
    // Center is (0, 0)
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = (size.width < size.height ? size.width : size.height) / 24.0;

    return Offset(
      cx + (lng * scale),
      cy - (lat * scale), // invert y for standard cartesian
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final locMap = {for (var l in locations) l.id: l};

    // Draw active road closures first (dashed/bold red line)
    for (var c in activeClosures) {
      if (c.fromLocation != null && c.toLocation != null) {
        final f = locMap[c.fromLocation!];
        final t = locMap[c.toLocation!];
        if (f != null && t != null && f.lat != null && t.lat != null) {
          final p1 = _toScreen(f.lat!, f.lng!, size);
          final p2 = _toScreen(t.lat!, t.lng!, size);
          final paint = Paint()
            ..color = AppTheme.rose.withOpacity(0.8)
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(p1, p2, paint);
        }
      }
    }

    // Draw vehicle routes
    if (plan != null) {
      final depot = locMap['DEPOT'];
      final depotOffset = depot != null && depot.lat != null
          ? _toScreen(depot.lat!, depot.lng!, size)
          : Offset(size.width / 2, size.height / 2);

      for (var v in plan!.vehicles) {
        if (highlightedVehicleId != null && v.id != highlightedVehicleId) {
          continue;
        }

        final color = _vehicleColor(v.id);
        final linePaint = Paint()
          ..color = v.isFailed ? AppTheme.textDim.withOpacity(0.3) : color.withOpacity(0.7)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round;

        final path = Path();
        path.moveTo(depotOffset.dx, depotOffset.dy);

        final sortedStops = List<StopModel>.from(v.stops)..sort((a, b) => a.seq.compareTo(b.seq));
        for (var stop in sortedStops) {
          final loc = locMap[stop.locationId];
          if (loc != null && loc.lat != null && loc.lng != null) {
            final pt = _toScreen(loc.lat!, loc.lng!, size);
            path.lineTo(pt.dx, pt.dy);
          }
        }

        canvas.drawPath(path, linePaint);
      }
    }

    // Draw location nodes
    for (var loc in locations) {
      if (loc.lat == null || loc.lng == null) continue;
      final pt = _toScreen(loc.lat!, loc.lng!, size);
      final isDepot = loc.id == 'DEPOT';

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
          ..color = AppTheme.amber.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(pt, 14, glowPaint);
      }

      final radius = isDepot ? 9.0 : 6.0;
      canvas.drawCircle(pt, radius, nodePaint);
      canvas.drawCircle(pt, radius, borderPaint);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: loc.id,
          style: TextStyle(
            color: isDepot ? AppTheme.amberLight : AppTheme.textMuted,
            fontSize: isDepot ? 11 : 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy + radius + 3));
    }
  }

  @override
  bool shouldRepaint(covariant NetworkPainter oldDelegate) => true;
}
