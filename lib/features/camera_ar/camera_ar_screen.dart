import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:astro_engine/astro_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/offline_sky_app.dart';
import '../../app/providers.dart';
import '../../core/astronomy/sky_snapshot.dart';
import '../../core/math/sky_math.dart';
import '../../core/models/celestial_target.dart';
import '../../core/models/device_orientation.dart';

class CameraArScreen extends ConsumerStatefulWidget {
  const CameraArScreen({required this.target, super.key});
  final CelestialTarget target;

  @override
  ConsumerState<CameraArScreen> createState() => _CameraArScreenState();
}

class _CameraArScreenState extends ConsumerState<CameraArScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _loading = true;
  bool _initializing = false;
  String? _error;
  double _cameraZoom = 1;
  double _gestureStartZoom = 1;
  double _minCameraZoom = 1;
  double _maxCameraZoom = 1;
  double _appliedCameraZoom = 1;
  bool _zoomRequestInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_initializing || !mounted) return;
    _initializing = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final cameras = await availableCameras();
      final camera = cameras
          .where((item) => item.lensDirection == CameraLensDirection.back)
          .firstOrNull;
      if (camera == null) {
        throw CameraException(
          'no_camera',
          'No rear-facing camera is available.',
        );
      }
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final old = _controller;
      _controller = controller;
      _minCameraZoom = minZoom;
      _maxCameraZoom = math.max(minZoom, maxZoom);
      _cameraZoom = 1.0.clamp(_minCameraZoom, _maxCameraZoom).toDouble();
      _appliedCameraZoom = _cameraZoom;
      if (old != null) {
        await old.dispose();
      }
      setState(() => _loading = false);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.description ?? error.code;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    } finally {
      _initializing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final camera = _controller;
      _controller = null;
      _zoomRequestInProgress = false;
      if (camera != null) {
        camera.dispose();
      }
    } else if (state == AppLifecycleState.resumed &&
        _controller == null &&
        !_initializing) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _onCameraScaleStart(ScaleStartDetails details) {
    _gestureStartZoom = _cameraZoom;
  }

  void _onCameraScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    final camera = _controller;
    if (camera?.value.isInitialized != true) return;
    final zoom = (_gestureStartZoom * details.scale)
        .clamp(_minCameraZoom, _maxCameraZoom)
        .toDouble();
    if ((zoom - _cameraZoom).abs() < .01) return;
    setState(() => _cameraZoom = zoom);
    unawaited(_applyPendingCameraZoom(camera!));
  }

  Future<void> _applyPendingCameraZoom(CameraController camera) async {
    if (_zoomRequestInProgress) return;
    _zoomRequestInProgress = true;
    try {
      while (mounted && identical(_controller, camera)) {
        final zoom = _cameraZoom;
        if ((zoom - _appliedCameraZoom).abs() < .01) break;
        await camera.setZoomLevel(zoom);
        _appliedCameraZoom = zoom;
      }
    } on CameraException {
      if (mounted && identical(_controller, camera)) {
        setState(() => _cameraZoom = _appliedCameraZoom);
      }
    } finally {
      _zoomRequestInProgress = false;
      if (mounted &&
          identical(_controller, camera) &&
          (_cameraZoom - _appliedCameraZoom).abs() >= .01) {
        unawaited(_applyPendingCameraZoom(camera));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(skySnapshotProvider).asData?.value;
    final orientation = ref.watch(orientationProvider).asData?.value;
    final verticalFov = ref.watch(cameraVerticalFovProvider);
    final overlayVerticalFov = _effectiveVerticalFov(verticalFov, _cameraZoom);
    final camera = _controller;
    final solar = widget.target.solarBody == null
        ? null
        : snapshot?.solar(widget.target.solarBody!);
    final catalog = widget.target.solarBody == null
        ? snapshot?.catalog(widget.target.id)
        : null;
    final targetAz = solar?.position.azimuthDegrees ?? catalog?.azimuthDegrees;
    final targetAlt =
        solar?.position.altitudeDegrees ?? catalog?.altitudeDegrees;
    final targetVector = targetAz == null || targetAlt == null
        ? null
        : EnuVector.fromAzimuthAltitude(targetAz, targetAlt);
    final direction = orientation != null && orientation.isAvailable
        ? orientation
        : null;
    final targetInView =
        targetVector != null &&
        direction != null &&
        targetVector.dot(direction.cameraForward) > 0;
    final cameraReady = camera?.value.isInitialized == true;
    final cameraZoomAvailable = _maxCameraZoom - _minCameraZoom > .01;
    final cameraStatus = cameraReady
        ? 'Camera ready'
        : _loading
        ? 'Camera starting'
        : 'Camera unavailable';
    final noticeDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onCameraScaleStart,
        onScaleUpdate: _onCameraScaleUpdate,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (camera?.value.isInitialized == true)
              _CameraPreviewCover(controller: camera!)
            else
              const ColoredBox(color: Color(0xFF090D14)),
            if (snapshot != null && direction != null)
              CustomPaint(
                painter: _CameraOverlayPainter(
                  snapshot: snapshot,
                  orientation: direction,
                  selectedId: widget.target.id,
                  selectedSolar: widget.target.solarBody,
                  verticalFieldOfViewDegrees: overlayVerticalFov,
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close camera',
                      ),
                      Expanded(
                        child: Text(
                          widget.target.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Semantics(
                          label: cameraStatus,
                          child: Icon(
                            Icons.circle,
                            size: 9,
                            color: cameraReady
                                ? const Color(0xFF7DE5B0)
                                : _loading
                                ? skyAccent
                                : const Color(0xFFFF9299),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: noticeDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _loading
                        ? const _CameraNotice(
                            key: ValueKey('camera-loading'),
                            icon: Icons.camera_alt_outlined,
                            text: 'Starting camera…',
                          )
                        : _error != null
                        ? _CameraNotice(
                            key: const ValueKey('camera-error'),
                            icon: Icons.no_photography_outlined,
                            text: 'Camera unavailable: $_error',
                            action: TextButton(
                              onPressed: _initializeCamera,
                              child: const Text('Try again'),
                            ),
                          )
                        : direction == null
                        ? const _CameraNotice(
                            key: ValueKey('orientation-unavailable'),
                            icon: Icons.explore_off_outlined,
                            text: 'Phone orientation is unavailable. Overlay alignment is hidden.',
                          )
                        : targetVector == null
                        ? const _CameraNotice(
                            key: ValueKey('position-unavailable'),
                            icon: Icons.location_off_outlined,
                            text: 'Set a location and wait for a sky calculation.',
                          )
                        : !targetInView
                        ? const _CameraNotice(
                            key: ValueKey('target-out-of-view'),
                            icon: Icons.screen_rotation_alt_outlined,
                            text: 'Target is outside this camera view. Turn toward its direction.',
                          )
                        : _CameraNotice(
                            key: const ValueKey('target-in-view'),
                            icon: Icons.center_focus_strong,
                            text:
                                '${cameraZoomAvailable ? 'Pinch to zoom' : 'Camera zoom unavailable'} · ${_cameraZoom.toStringAsFixed(1)}× · overlay FOV ≈ ${_horizontalFov(overlayVerticalFov, MediaQuery.sizeOf(context))}° × ${overlayVerticalFov.round()}° · calibration is approximate',
                            color: skySurface.withValues(alpha: .86),
                          ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPreviewCover extends StatelessWidget {
  const _CameraPreviewCover({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final previewSize = controller.value.previewSize;
      if (previewSize == null) return CameraPreview(controller);
      final portrait =
          MediaQuery.orientationOf(context) == Orientation.portrait;
      final sourceAspect = controller.value.aspectRatio;
      final displayAspect = portrait ? 1 / sourceAspect : sourceAspect;
      final childHeight = previewSize.height;
      final childWidth = childHeight * displayAspect;
      return SizedBox.expand(
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: childWidth,
              height: childHeight,
              child: CameraPreview(controller),
            ),
          ),
        ),
      );
    },
  );
}

class _CameraOverlayPainter extends CustomPainter {
  const _CameraOverlayPainter({
    required this.snapshot,
    required this.orientation,
    required this.selectedId,
    required this.selectedSolar,
    required this.verticalFieldOfViewDegrees,
  });
  final SkySnapshot snapshot;
  final DeviceOrientation orientation;
  final String selectedId;
  final SolarBody? selectedSolar;
  final double verticalFieldOfViewDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    final fovY = verticalFieldOfViewDegrees * math.pi / 180;
    final fovX = 2 * math.atan(math.tan(fovY / 2) * size.width / size.height);
    final targets =
        <({String id, String name, EnuVector vector, bool selected})>[];
    for (final point in snapshot.solarPoints) {
      targets.add((
        id: 'solar:${point.body.name}',
        name: _solarName(point.body),
        vector: point.direction,
        selected: point.body == selectedSolar,
      ));
    }
    for (final point in snapshot.catalogPoints) {
      if (point.object.id == selectedId ||
          (point.object.magnitude != null &&
              point.object.magnitude! <= 2.5 &&
              point.altitudeDegrees > 0)) {
        targets.add((
          id: point.object.id,
          name: point.object.name,
          vector: point.direction,
          selected: point.object.id == selectedId,
        ));
      }
    }
    for (final target in targets) {
      final forward = target.vector.dot(orientation.cameraForward);
      if (forward <= 0) continue;
      final horizontal = math.atan2(
        target.vector.dot(orientation.screenRight),
        forward,
      );
      final vertical = math.atan2(
        target.vector.dot(orientation.screenUp),
        forward,
      );
      if (horizontal.abs() > fovX / 2 || vertical.abs() > fovY / 2) continue;
      final center = Offset(
        size.width / 2 + horizontal / fovX * size.width,
        size.height / 2 - vertical / fovY * size.height,
      );
      final color = target.selected ? skyGold : skyAccent;
      final paint = Paint()..color = color;
      canvas.drawCircle(
        center,
        target.selected ? 9 : 4,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = target.selected ? 2.5 : 1.5,
      );
      if (target.selected) {
        canvas.drawCircle(center, 2.5, paint..style = PaintingStyle.fill);
      }
      final text = TextPainter(
        text: TextSpan(
          text: target.name,
          style: TextStyle(
            color: color,
            fontSize: target.selected ? 14 : 10,
            fontWeight: target.selected ? FontWeight.w700 : FontWeight.w500,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 140);
      text.paint(canvas, center + Offset(9, -text.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CameraOverlayPainter oldDelegate) =>
      oldDelegate.snapshot != snapshot ||
      oldDelegate.orientation.timestamp != orientation.timestamp ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.verticalFieldOfViewDegrees != verticalFieldOfViewDegrees;
}

class _CameraNotice extends StatelessWidget {
  const _CameraNotice({
    super.key,
    required this.icon,
    required this.text,
    this.action,
    this.color,
  });
  final IconData icon;
  final String text;
  final Widget? action;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 18),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: color ?? skySurface.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: skyAccent),
        const SizedBox(width: 11),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, height: 1.35)),
        ),
        ?action,
      ],
    ),
  );
}

String _solarName(SolarBody body) {
  final value = body.name;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String _horizontalFov(double verticalDegrees, Size screenSize) {
  final verticalRadians = verticalDegrees * math.pi / 180;
  return (2 *
          math.atan(
            math.tan(verticalRadians / 2) *
                screenSize.width /
                screenSize.height,
          ) *
          180 /
          math.pi)
      .round()
      .toString();
}

double _effectiveVerticalFov(double verticalDegrees, double zoom) {
  final halfAngle = verticalDegrees * math.pi / 360;
  return 2 * math.atan(math.tan(halfAngle) / zoom) * 180 / math.pi;
}
