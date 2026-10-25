import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/offline_sky_app.dart';
import '../../app/providers.dart';
import '../../core/astronomy/sky_snapshot.dart';
import '../../core/math/sky_math.dart';
import '../../core/models/celestial_object.dart';
import '../../core/models/celestial_target.dart';
import '../../core/models/observer_location.dart';
import '../../core/rendering/sky_projection.dart';
import '../../shared/location_editor.dart';
import '../../shared/sky_format.dart';
import '../object_details/object_details_screen.dart';

class SkyScreen extends ConsumerStatefulWidget {
  const SkyScreen({super.key});

  @override
  ConsumerState<SkyScreen> createState() => _SkyScreenState();
}

class _SkyScreenState extends ConsumerState<SkyScreen> {
  double _centerAzimuth = 180;
  double _centerAltitude = 35;
  double _fieldOfView = 75;
  double _startFov = 75;
  Offset? _lastPanPoint;
  bool _deviceFollow = false;

  @override
  Widget build(BuildContext context) {
    final skyAsync = ref.watch(skySnapshotProvider);
    final state = ref.watch(skyStateProvider);
    final orientation = ref.watch(orientationProvider).asData?.value;
    final motionDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final now = state.currentTime;
    final follows = _deviceFollow && orientation?.isAvailable == true;
    final viewAz = follows
        ? _azimuthOf(orientation!.cameraForward)
        : _centerAzimuth;
    final viewAlt = follows
        ? _altitudeOf(orientation!.cameraForward)
        : _centerAltitude;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 6),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Offline planetarium'),
                        const SizedBox(height: 4),
                        Text(
                          'Look up',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 13),
            sliver: SliverToBoxAdapter(
              child: _LocationSummary(
                state: state,
                onDetect: () =>
                    ref.read(skyStateProvider.notifier).detectLocation(),
                onManual: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const LocationEditorSheet(),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: skyAccent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${state.liveTime ? 'LIVE' : 'TIME TRAVEL'} · ${localTimestamp(now.toUtc())}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        letterSpacing: .4,
                        color: state.liveTime
                            ? const Color(0xFF9DABC0)
                            : skyGold,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: motionDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: state.liveTime
                        ? const SizedBox.shrink(key: ValueKey('now-hidden'))
                        : TextButton(
                            key: const ValueKey('return-to-now'),
                            onPressed: () =>
                                ref.read(skyStateProvider.notifier).setNow(),
                            child: const Text('Now'),
                          ),
                  ),
                  IconButton(
                    onPressed: () => _chooseTime(context, state),
                    tooltip: 'Change observation time',
                    icon: const Icon(Icons.edit_calendar_outlined, size: 19),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sky = skyAsync.asData?.value;
                  if (sky != null) {
                    return SizedBox(
                      height: constraints.maxWidth / .94,
                      child: _InteractiveSkyMap(
                        snapshot: sky,
                        centerAzimuth: viewAz,
                        centerAltitude: viewAlt,
                        fieldOfView: _fieldOfView,
                        followingDevice: follows,
                        onToggleFollow: () =>
                            setState(() => _deviceFollow = !_deviceFollow),
                        onScaleStart: (details) {
                          _startFov = _fieldOfView;
                          _lastPanPoint = details.focalPoint;
                        },
                        onScaleUpdate: (details, size) {
                          if (_deviceFollow &&
                              orientation?.isAvailable == true) {
                            return;
                          }
                          final last = _lastPanPoint;
                          final delta = last == null
                              ? Offset.zero
                              : details.focalPoint - last;
                          _lastPanPoint = details.focalPoint;
                          setState(() {
                            _fieldOfView = (_startFov / details.scale).clamp(
                              32.0,
                              150.0,
                            );
                            _centerAzimuth = normalizeAzimuth(
                              _centerAzimuth -
                                  delta.dx * _fieldOfView / size.width,
                            );
                            _centerAltitude =
                                (_centerAltitude +
                                        delta.dy * _fieldOfView / size.height)
                                    .clamp(-20.0, 90.0);
                          });
                        },
                        onZoom: (factor) => setState(
                          () => _fieldOfView = (_fieldOfView * factor).clamp(
                            32.0,
                            150.0,
                          ),
                        ),
                        onTap: (target) => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ObjectDetailsScreen(target: target),
                          ),
                        ),
                      ),
                    );
                  }
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxWidth / .94,
                    ),
                    child: skyAsync.when(
                      loading: () => const _SkyLoading(),
                      error: (error, _) => _SkyError(message: '$error'),
                      data: (_) => const _NoLocationSky(),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 9),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sky = skyAsync.asData?.value;
                  return Row(
                    children: [
                      const Icon(
                        Icons.touch_app_outlined,
                        size: 16,
                        color: skyAccent,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Drag to explore · pinch to zoom · tap an object',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF9AA8BD)),
                        ),
                      ),
                      if (sky != null && constraints.maxWidth >= 320)
                        InfoChip(
                          icon: Icons.public,
                          label: '${sky.constellations.length} constellations',
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (skyAsync.asData?.value case final sky?)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 11, 18, 24),
              sliver: SliverToBoxAdapter(
                child: _VisibleObjects(
                  snapshot: sky,
                  onSelect: (target) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ObjectDetailsScreen(target: target),
                    ),
                  ),
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Future<void> _chooseTime(BuildContext context, SkyState state) async {
    final initial = state.currentTime.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      helpText: 'Choose observation date',
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Choose local time',
    );
    if (time == null || !context.mounted) return;
    await ref
        .read(skyStateProvider.notifier)
        .setSelectedTime(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
  }
}

class _InteractiveSkyMap extends StatefulWidget {
  const _InteractiveSkyMap({
    required this.snapshot,
    required this.centerAzimuth,
    required this.centerAltitude,
    required this.fieldOfView,
    required this.followingDevice,
    required this.onToggleFollow,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onZoom,
    required this.onTap,
  });
  final SkySnapshot snapshot;
  final double centerAzimuth;
  final double centerAltitude;
  final double fieldOfView;
  final bool followingDevice;
  final VoidCallback onToggleFollow;
  final GestureScaleStartCallback onScaleStart;
  final void Function(ScaleUpdateDetails details, Size size) onScaleUpdate;
  final void Function(double factor) onZoom;
  final void Function(CelestialTarget target) onTap;

  @override
  State<_InteractiveSkyMap> createState() => _InteractiveSkyMapState();
}

class _InteractiveSkyMapState extends State<_InteractiveSkyMap> {
  Size? _size;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = Size(constraints.maxWidth, constraints.maxHeight);
      final compactControls = constraints.maxWidth < 164;
      return ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.15, -.2),
              radius: 1.1,
              colors: [Color(0xFF17243A), Color(0xFF080D18)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                container: true,
                label: 'Interactive sky map. Drag to explore, pinch to zoom, and tap a visible object for details.',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: widget.onScaleStart,
                  onScaleUpdate: (details) =>
                      widget.onScaleUpdate(details, _size!),
                  onTapUp: (details) => _selectAt(details.localPosition),
                  child: CustomPaint(
                    painter: _SkyMapPainter(
                      snapshot: widget.snapshot,
                      projection: SkyProjection(
                        centerAzimuthDegrees: widget.centerAzimuth,
                        centerAltitudeDegrees: widget.centerAltitude,
                        fieldOfViewDegrees: widget.fieldOfView,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _MapControl(
                  icon: Icons.zoom_out,
                  tooltip: 'Zoom out',
                  onPressed: () => widget.onZoom(1.15),
                ),
              ),
              Positioned(
                left: compactControls ? 12 : 64,
                top: compactControls ? 64 : 12,
                child: _MapControl(
                  icon: Icons.zoom_in,
                  tooltip: 'Zoom in',
                  onPressed: () => widget.onZoom(.87),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: _MapControl(
                  icon: widget.followingDevice
                      ? Icons.explore
                      : Icons.explore_outlined,
                  active: widget.followingDevice,
                  onPressed: widget.onToggleFollow,
                  tooltip: 'Follow phone orientation',
                  size: 48,
                ),
              ),
              Positioned(
                left: 14,
                bottom: 13,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.fieldOfView.round()}° field · geometric sky',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFB2C0D4),
                    ),
                  ),
                ),
              ),
              const Positioned(
                right: 17,
                bottom: 14,
                child: Text(
                  'N',
                  style: TextStyle(
                    color: Color(0xFFAFBED3),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  void _selectAt(Offset position) {
    final size = _size;
    if (size == null) return;
    final projection = SkyProjection(
      centerAzimuthDegrees: widget.centerAzimuth,
      centerAltitudeDegrees: widget.centerAltitude,
      fieldOfViewDegrees: widget.fieldOfView,
    );
    Offset? nearest;
    CelestialTarget? target;
    var minDistance = 27.0;
    for (final point in widget.snapshot.solarPoints) {
      final projected = projection.projectVector(point.direction, size);
      final distance = projected == null
          ? null
          : (projected.dx - position.dx) * (projected.dx - position.dx) +
                (projected.dy - position.dy) * (projected.dy - position.dy);
      if (distance != null && distance < minDistance * minDistance) {
        minDistance = math.sqrt(distance);
        nearest = projected;
        target = CelestialTarget.solar(point.body);
      }
    }
    for (final point in widget.snapshot.catalogPoints) {
      final projected = projection.projectVector(point.direction, size);
      final distance = projected == null
          ? null
          : (projected.dx - position.dx) * (projected.dx - position.dx) +
                (projected.dy - position.dy) * (projected.dy - position.dy);
      if (distance != null && distance < minDistance * minDistance) {
        minDistance = math.sqrt(distance);
        nearest = projected;
        target = CelestialTarget.catalog(point.object);
      }
    }
    if (nearest != null && target != null) widget.onTap(target);
  }
}

class _SkyMapPainter extends CustomPainter {
  const _SkyMapPainter({required this.snapshot, required this.projection});
  final SkySnapshot snapshot;
  final SkyProjection projection;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _drawGrid(canvas, size);
    _drawMilkyWay(canvas, size);
    final starMagnitudeLimit = starMagnitudeLimitForFieldOfView(
      projection.fieldOfViewDegrees,
    );
    final deepSkyLabelLimit = (4.4 - projection.fieldOfViewDegrees * .015)
        .clamp(2.4, 4.0);
    final linePaint = Paint()
      ..color = const Color(0xFF7899C5).withValues(alpha: .34)
      ..strokeWidth = 1.05
      ..style = PaintingStyle.stroke;
    for (final constellation in snapshot.constellationPaths) {
      final path = Path();
      var started = false;
      for (final direction in constellation.directions) {
        final projected = projection.projectVector(direction, size);
        if (projected == null) {
          started = false;
          continue;
        }
        if (!started) {
          path.moveTo(projected.dx, projected.dy);
          started = true;
        } else {
          path.lineTo(projected.dx, projected.dy);
        }
      }
      canvas.drawPath(path, linePaint);
    }
    for (final label in snapshot.constellationLabels) {
      final position = projection.projectVector(label.direction, size);
      if (position != null && label.direction.up >= 0) {
        _drawLabel(
          canvas,
          label.name,
          position,
          const Color(0xFFA8B8D0).withValues(alpha: .72),
          8,
        );
      }
    }
    for (final point in snapshot.catalogPoints) {
      final isStar = point.object.type.name == 'star';
      final isBlackHole = point.object.type == CelestialType.blackHole;
      final isMilkyWayMarker = point.object.id == 'galaxy:milky-way';
      final magnitude = point.object.magnitude;
      if (point.altitudeDegrees < -5 ||
          (isStar && (magnitude == null || magnitude > starMagnitudeLimit))) {
        continue;
      }
      if (!isStar &&
          !isBlackHole &&
          !isMilkyWayMarker &&
          (magnitude == null || magnitude > 6.5)) {
        continue;
      }
      final position = projection.projectVector(point.direction, size);
      if (position == null) {
        continue;
      }
      final radius = isStar
          ? (3.05 - (magnitude ?? 5.5) * .32).clamp(.65, 3.2)
          : 3.2;
      final alpha = point.altitudeDegrees < 0 ? .22 : .88;
      final color = isBlackHole || isMilkyWayMarker
          ? const Color(0xFFDB9CFF).withValues(alpha: alpha)
          : isStar
          ? const Color(0xFFE5EDFF).withValues(alpha: alpha)
          : const Color(0xFF65C8FF).withValues(alpha: alpha);
      canvas.drawCircle(
        position,
        isBlackHole ? 4 : radius.toDouble(),
        Paint()..color = color,
      );
      if (point.altitudeDegrees >= 0 &&
          (isBlackHole ||
              isMilkyWayMarker ||
              (!isStar &&
                  magnitude != null &&
                  magnitude < deepSkyLabelLimit))) {
        _drawLabel(
          canvas,
          point.object.name,
          position +
              (isMilkyWayMarker ? const Offset(12, 8) : const Offset(6, -7)),
          isBlackHole || isMilkyWayMarker
              ? const Color(0xFFE2BCFF)
              : const Color(0xFF8BD9FF),
          9,
        );
      }
    }
    for (final point in snapshot.solarPoints) {
      final position = projection.projectVector(point.direction, size);
      if (position == null) continue;
      final color = point.body.name == 'sun'
          ? skyGold
          : point.body.name == 'moon'
          ? const Color(0xFFECF2FF)
          : const Color(0xFF80CEFF);
      final radius = point.body.name == 'sun'
          ? 7.0
          : point.body.name == 'moon'
          ? 6.0
          : 4.4;
      canvas.drawCircle(
        position,
        radius + 5,
        Paint()..color = color.withValues(alpha: .12),
      );
      canvas.drawCircle(position, radius, Paint()..color = color);
      _drawLabel(
        canvas,
        _solarName(point.body.name),
        position + Offset(8, -9),
        color,
        11,
      );
    }
    canvas.restore();
  }

  void _drawMilkyWay(Canvas canvas, Size size) {
    if (snapshot.milkyWayCurves.length != 3) return;
    final radius = math.min(size.width, size.height) * .46;
    final width =
        (radius *
                2 *
                math.tan(5 * math.pi / 180) /
                math.tan(projection.fieldOfViewDegrees * math.pi / 360))
            .clamp(2.0, radius * 1.4);
    final centralPath = _vectorPath(snapshot.milkyWayCurves[1], size);
    canvas.drawPath(
      centralPath,
      Paint()
        ..color = const Color(0xFFB6A7C8).withValues(alpha: .095)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    for (final edge in [
      snapshot.milkyWayCurves.first,
      snapshot.milkyWayCurves.last,
    ]) {
      canvas.drawPath(
        _vectorPath(edge, size),
        Paint()
          ..color = const Color(0xFFCEBEDD).withValues(alpha: .16)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }
    final center = Offset(size.width / 2, size.height / 2);
    final visible = snapshot.milkyWayCurves[1]
        .map((vector) => projection.projectVector(vector, size))
        .whereType<Offset>()
        .toList(growable: false);
    if (visible.isNotEmpty) {
      visible.sort(
        (a, b) => (a - center).distanceSquared.compareTo(
          (b - center).distanceSquared,
        ),
      );
      _drawLabel(
        canvas,
        'Milky Way',
        visible.first + const Offset(7, 8),
        const Color(0xFFD2C4E0),
        9,
      );
    }
  }

  Path _vectorPath(List<EnuVector> vectors, Size size) {
    final path = Path();
    var started = false;
    for (final vector in vectors) {
      final point = projection.projectVector(vector, size);
      if (point == null) {
        started = false;
      } else if (!started) {
        path.moveTo(point.dx, point.dy);
        started = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  void _drawGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF546985).withValues(alpha: .28)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
    for (final altitude in [0.0, 30.0, 60.0]) {
      _curve(canvas, size, grid, (step) => (step * 360 / 90, altitude));
      if (altitude > 0) {
        final label = projection.project(
          projection.centerAzimuthDegrees,
          altitude,
          size,
        );
        if (label != null) {
          _drawLabel(
            canvas,
            '${altitude.round()}°',
            label + const Offset(5, -3),
            const Color(0xFF7889A2),
            9,
          );
        }
      }
    }
    for (var azimuth = 0; azimuth < 360; azimuth += 30) {
      _curve(
        canvas,
        size,
        grid,
        (step) => (azimuth.toDouble(), -10 + step * 100 / 30),
      );
      if (azimuth % 90 == 0) {
        final label = projection.project(azimuth.toDouble(), 0, size);
        if (label != null) {
          _drawLabel(
            canvas,
            const ['N', 'E', 'S', 'W'][azimuth ~/ 90],
            label,
            const Color(0xFFC0CEE2),
            10,
          );
        }
      }
    }
    final horizon = Paint()
      ..color = const Color(0xFF8394AE).withValues(alpha: .62)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    _curve(canvas, size, horizon, (step) => (step * 4.0, 0));
  }

  void _curve(
    Canvas canvas,
    Size size,
    Paint paint,
    (double, double) Function(int) coordinate,
  ) {
    final path = Path();
    var started = false;
    for (var step = 0; step <= 90; step++) {
      final (az, alt) = coordinate(step);
      final point = projection.project(az, alt, size);
      if (point == null) {
        started = false;
        continue;
      }
      if (!started) {
        path.moveTo(point.dx, point.dy);
        started = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
    double fontSize,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 100);
    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _SkyMapPainter oldDelegate) =>
      oldDelegate.snapshot != snapshot ||
      oldDelegate.projection.centerAzimuthDegrees !=
          projection.centerAzimuthDegrees ||
      oldDelegate.projection.centerAltitudeDegrees !=
          projection.centerAltitudeDegrees ||
      oldDelegate.projection.fieldOfViewDegrees !=
          projection.fieldOfViewDegrees;
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary({
    required this.state,
    required this.onDetect,
    required this.onManual,
  });
  final SkyState state;
  final VoidCallback onDetect;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final location = state.location;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: skyAccent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.location_on_outlined, color: skyAccent),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location == null
                        ? 'Observer location'
                        : location.source == LocationSource.gps
                        ? 'Current GPS location'
                        : 'Saved observer location',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    location == null
                        ? state.locationMessage ??
                              'Required to calculate your local sky'
                        : '${location.latitudeDegrees.toStringAsFixed(4)}°, ${location.longitudeDegrees.toStringAsFixed(4)}° · ${location.elevationMeters.round()} m',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF9AA8BD)),
                  ),
                  if (location?.horizontalAccuracyMeters != null)
                    Text(
                      'Reported accuracy ±${location!.horizontalAccuracyMeters!.round()} m',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: const Color(0xFF7889A2)),
                    ),
                ],
              ),
            ),
            if (location == null)
              IconButton(
                onPressed: state.isLocating ? null : onDetect,
                tooltip: 'Detect GPS location',
                icon: state.isLocating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, color: skyAccent),
              ),
            IconButton(
              onPressed: onManual,
              tooltip: 'Edit observer location',
              icon: const Icon(Icons.edit_location_alt_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibleObjects extends StatelessWidget {
  const _VisibleObjects({required this.snapshot, required this.onSelect});
  final SkySnapshot snapshot;
  final void Function(CelestialTarget target) onSelect;

  @override
  Widget build(BuildContext context) {
    final visible =
        snapshot.solarPoints
            .where((item) => item.position.altitudeDegrees >= 0)
            .toList()
          ..sort(
            (a, b) => b.position.altitudeDegrees.compareTo(
              a.position.altitudeDegrees,
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Planets & Moon',
          action: Text(
            '${visible.length} up',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: const Color(0xFF9AA8BD)),
          ),
        ),
        const SizedBox(height: 11),
        if (visible.isEmpty)
          const Text(
            'The Sun, Moon, and planets are below the horizon at this time.',
            style: TextStyle(color: Color(0xFF9AA8BD)),
          )
        else
          SizedBox(
            height: 107,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final item = visible[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onSelect(CelestialTarget.solar(item.body)),
                  child: Container(
                    width: 124,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: skySurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF26334A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.body.name == 'sun'
                              ? Icons.wb_sunny_outlined
                              : item.body.name == 'moon'
                              ? Icons.nightlight_outlined
                              : Icons.public,
                          color: item.body.name == 'sun' ? skyGold : skyAccent,
                          size: 21,
                        ),
                        const Spacer(),
                        Text(
                          _solarName(item.body.name),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${item.position.altitudeDegrees.round()}° high',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: const Color(0xFF9AA8BD)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.tooltip,
    this.size = 48,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) => Material(
    color: active
        ? skyAccent.withValues(alpha: .9)
        : Colors.black.withValues(alpha: .48),
    borderRadius: BorderRadius.circular(13),
    child: IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Semantics(
        label: tooltip,
        child: Icon(
          icon,
          size: 19,
          color: active ? const Color(0xFF07111D) : const Color(0xFFDCE6F5),
        ),
      ),
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
    ),
  );
}

class _SkyLoading extends StatelessWidget {
  const _SkyLoading();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: skySurface,
      borderRadius: BorderRadius.all(Radius.circular(26)),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Preparing the local sky catalog…'),
        ],
      ),
    ),
  );
}

class _SkyError extends StatelessWidget {
  const _SkyError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: skySurface,
      borderRadius: BorderRadius.all(Radius.circular(26)),
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Sky calculation failed\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _NoLocationSky extends StatelessWidget {
  const _NoLocationSky();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: skySurface,
      borderRadius: BorderRadius.all(Radius.circular(26)),
    ),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_searching, size: 38, color: skyAccent),
            SizedBox(height: 12),
            Text(
              'Choose a location to calculate the sky',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 7),
            Text(
              'No example or simulated sky positions are shown.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9AA8BD)),
            ),
          ],
        ),
      ),
    ),
  );
}

String _solarName(String name) => name[0].toUpperCase() + name.substring(1);
double _azimuthOf(EnuVector vector) =>
    normalizeAzimuth(math.atan2(vector.east, vector.north) * 180 / math.pi);
double _altitudeOf(EnuVector vector) =>
    math.asin(vector.up.clamp(-1.0, 1.0)) * 180 / math.pi;
