import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/offline_sky_app.dart';
import '../../app/providers.dart';
import '../../core/astronomy/sky_snapshot.dart';
import '../../core/math/sky_math.dart';
import '../../core/models/celestial_target.dart';
import '../../core/models/device_orientation.dart';
import '../../shared/sky_format.dart';

class LocatorScreen extends ConsumerWidget {
  const LocatorScreen({required this.target, super.key});

  final CelestialTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(skySnapshotProvider);
    final orientation = ref.watch(orientationProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Find ${target.name}')),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Position unavailable: $error')),
        data: (sky) {
          if (sky == null) {
            return const _LocatorMessage(
              icon: Icons.location_off_outlined,
              title: 'Location needed',
              body: 'Set a GPS or manual observer location before finding objects in your local sky.',
            );
          }
          final solar = target.solarBody == null
              ? null
              : sky.solar(target.solarBody!);
          final catalog = target.solarBody == null
              ? sky.catalog(target.id)
              : null;
          final azimuth =
              solar?.position.azimuthDegrees ?? catalog?.azimuthDegrees;
          final altitude =
              solar?.position.altitudeDegrees ?? catalog?.altitudeDegrees;
          if (azimuth == null || altitude == null) {
            return const _LocatorMessage(
              icon: Icons.error_outline,
              title: 'No position available',
              body: 'The catalog does not contain valid coordinates for this object.',
            );
          }
          final direction = orientation.asData?.value;
          ObjectAlignment? alignment;
          if (direction != null && direction.isAvailable) {
            alignment = calculateAlignment(
              target: EnuVector.fromAzimuthAltitude(azimuth, altitude),
              cameraForward: direction.cameraForward,
              screenRight: direction.screenRight,
              screenUp: direction.screenUp,
              toleranceDegrees: 2,
            );
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scopeSize = math
                      .min(260.0, math.max(150.0, constraints.maxHeight * .38))
                      .toDouble();
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Eyebrow('Live pointing guide'),
                          const SizedBox(height: 7),
                          Text(
                            target.name,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${compassDirection(azimuth)}  ${azimuth.toStringAsFixed(1)}°  ·  Alt ${formatAngle(altitude, signed: true)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF9FAEC4)),
                          ),
                          SizedBox(
                            height: constraints.maxHeight < 480 ? 12 : 23,
                          ),
                          if (altitude < 0)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3A2E1B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF70552A),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_amber, color: skyGold),
                                  SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      'This object is below the geometric horizon at this time.',
                                      style: TextStyle(
                                        color: Color(0xFFF2D497),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(
                            height: scopeSize,
                            child: Center(
                              child: _AlignmentScope(
                                size: scopeSize,
                                targetName: target.name,
                                orientation: direction,
                                alignment: alignment,
                              ),
                            ),
                          ),
                          if (alignment != null) ...[
                            Text(
                              alignment.isAligned
                                  ? 'ALIGNED'
                                  : _directionInstruction(alignment),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: alignment.isAligned
                                        ? const Color(0xFF7DE5B0)
                                        : skyAccent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${alignment.angularSeparationDegrees.toStringAsFixed(1)}° from center · 2° alignment tolerance',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF9AA8BD)),
                            ),
                            const SizedBox(height: 16),
                            _SensorQuality(orientation: direction!),
                          ] else ...[
                            const Text(
                              'Phone orientation is unavailable',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This device or platform did not provide a motion update. Use the azimuth and altitude above with a physical compass.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF9AA8BD)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlignmentScope extends StatelessWidget {
  const _AlignmentScope({
    required this.size,
    required this.targetName,
    required this.orientation,
    required this.alignment,
  });

  final double size;
  final String targetName;
  final DeviceOrientation? orientation;
  final ObjectAlignment? alignment;

  @override
  Widget build(BuildContext context) {
    final available = orientation?.isAvailable == true && alignment != null;
    final motionDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 90);
    final x = available
        ? (alignment!.horizontalErrorDegrees / 40).clamp(-1.0, 1.0) * 100
        : 0.0;
    final y = available
        ? -(alignment!.verticalErrorDegrees / 40).clamp(-1.0, 1.0) * 100
        : 0.0;
    final markerOffset = Offset(x.toDouble(), y.toDouble());
    final maxMarkerDisplacement = size / 2 - 12;
    final markerDistance = markerOffset.distance;
    final boundedMarkerOffset = markerDistance > maxMarkerDisplacement
        ? markerOffset * (maxMarkerDisplacement / markerDistance)
        : markerOffset;
    final color = alignment?.isAligned == true
        ? const Color(0xFF7DE5B0)
        : skyAccent;
    final summary = !available
        ? 'Phone orientation is unavailable.'
        : alignment!.isAligned
        ? 'Target is centered.'
        : _directionInstruction(alignment!);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Direction guide for $targetName. $summary',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: skySurface,
                border: Border.all(color: const Color(0xFF263650), width: 1.5),
              ),
            ),
            CustomPaint(
              size: Size(size, size),
              painter: _ScopePainter(color: color),
            ),
            AnimatedPositioned(
              duration: motionDuration,
              curve: Curves.easeOut,
              left: size / 2 - 10 + boundedMarkerOffset.dx,
              top: size / 2 - 10 + boundedMarkerOffset.dy,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
            if (!available)
              const Icon(
                Icons.explore_outlined,
                color: Color(0xFF64738A),
                size: 32,
              ),
            const Positioned(
              top: 17,
              child: Text(
                'UP',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: Color(0xFF7C8EA8),
                ),
              ),
            ),
            const Positioned(
              bottom: 17,
              child: Text(
                'DOWN',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: Color(0xFF7C8EA8),
                ),
              ),
            ),
            const Positioned(
              left: 18,
              child: Text(
                'LEFT',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: Color(0xFF7C8EA8),
                ),
              ),
            ),
            const Positioned(
              right: 18,
              child: Text(
                'RIGHT',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: Color(0xFF7C8EA8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopePainter extends CustomPainter {
  const _ScopePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF31415A)
      ..strokeWidth = 1;
    for (final fraction in [.27, .52, .76]) {
      canvas.drawCircle(
        center,
        size.width * fraction / 2,
        paint..style = PaintingStyle.stroke,
      );
    }
    canvas.drawLine(
      Offset(center.dx - size.width * .35, center.dy),
      Offset(center.dx + size.width * .35, center.dy),
      paint..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size.height * .35),
      Offset(center.dx, center.dy + size.height * .35),
      paint..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      center,
      3.5,
      Paint()..color = color.withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(covariant _ScopePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _SensorQuality extends StatelessWidget {
  const _SensorQuality({required this.orientation});
  final DeviceOrientation orientation;

  @override
  Widget build(BuildContext context) {
    final quality = switch (orientation.quality) {
      OrientationQuality.high => 'Good sensor confidence',
      OrientationQuality.medium => 'Moderate sensor confidence',
      OrientationQuality.low => 'Low sensor confidence · calibrate by moving the phone in a figure eight',
      OrientationQuality.unavailable => 'Sensor confidence unavailable',
    };
    final reference = switch (orientation.northReference) {
      NorthReference.trueNorth => 'True north',
      NorthReference.magneticNorth => 'Magnetic north',
      NorthReference.unavailable => 'North reference unavailable',
    };
    final accuracy = orientation.headingAccuracyDegrees;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: skySurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            orientation.quality == OrientationQuality.high
                ? Icons.my_location
                : Icons.explore_outlined,
            color: skyAccent,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quality,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '$reference${accuracy == null ? '' : ' · ±${accuracy.toStringAsFixed(0)}° heading estimate'}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: const Color(0xFF93A2B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _directionInstruction(ObjectAlignment alignment) {
  final horizontal = alignment.horizontalErrorDegrees.abs() > 1.5
      ? '${alignment.horizontalErrorDegrees > 0 ? 'right' : 'left'} ${alignment.horizontalErrorDegrees.abs().round()}°'
      : '';
  final vertical = alignment.verticalErrorDegrees.abs() > 1.5
      ? '${alignment.verticalErrorDegrees > 0 ? 'up' : 'down'} ${alignment.verticalErrorDegrees.abs().round()}°'
      : '';
  if (horizontal.isEmpty && vertical.isEmpty) return 'Move phone slowly';
  return 'Move ${[horizontal, vertical].where((part) => part.isNotEmpty).join(' · ')}';
}

class _LocatorMessage extends StatelessWidget {
  const _LocatorMessage({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: skyAccent),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9AA8BD)),
          ),
        ],
      ),
    ),
  );
}
