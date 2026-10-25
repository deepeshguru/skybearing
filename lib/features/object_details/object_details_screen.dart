import 'package:astro_engine/astro_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/offline_sky_app.dart';
import '../../app/providers.dart';
import '../../core/astronomy/sky_snapshot.dart';
import '../../core/models/celestial_target.dart';
import '../../features/object_locator/locator_screen.dart';
import '../../features/camera_ar/camera_ar_screen.dart';
import '../../shared/sky_format.dart';

class ObjectDetailsScreen extends ConsumerWidget {
  const ObjectDetailsScreen({required this.target, super.key});

  final CelestialTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(skySnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Object details')),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not calculate this position: $error')),
        data: (snapshot) {
          final solar = target.solarBody == null
              ? null
              : snapshot?.solar(target.solarBody!);
          final catalog = target.solarBody == null
              ? snapshot?.catalog(target.id)
              : null;
          final azimuth =
              solar?.position.azimuthDegrees ?? catalog?.azimuthDegrees;
          final altitude =
              solar?.position.altitudeDegrees ?? catalog?.altitudeDegrees;
          final ra =
              solar?.position.rightAscensionHours ??
              catalog?.rightAscensionHours;
          final dec =
              solar?.position.declinationDegrees ?? catalog?.declinationDegrees;
          final isAbove = altitude != null && altitude >= 0;
          final isFavorite = ref
              .watch(skyStateProvider)
              .favorites
              .contains(target.id);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: skyAccent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _iconFor(target.kind),
                      color: skyAccent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          target.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${target.kind}  ·  ${target.id}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF95A6BF)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isFavorite
                        ? 'Remove from favorites'
                        : 'Save favorite',
                    onPressed: () => ref
                        .read(skyStateProvider.notifier)
                        .toggleFavorite(target.id),
                    icon: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: Icon(
                        key: ValueKey(isFavorite),
                        isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                        color: isFavorite ? skyGold : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                target.description,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.45, color: const Color(0xFFB7C3D7)),
              ),
              const SizedBox(height: 22),
              if (snapshot == null)
                const _DetailNotice(
                  icon: Icons.location_off_outlined,
                  title: 'Set an observer location',
                  body: 'Position in the local sky needs latitude, longitude, and elevation. Add a GPS or manual location in Settings.',
                )
              else if (azimuth == null || altitude == null)
                const _DetailNotice(
                  icon: Icons.error_outline,
                  title: 'Position unavailable',
                  body: 'The selected object has no usable reference coordinates in this catalog.',
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [skyElevated, skySurface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF2A3850)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isAbove
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: isAbove ? skyAccent : skyGold,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              isAbove
                                  ? 'Above the geometric horizon'
                                  : 'Below the geometric horizon',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _ValueBlock(
                              label: 'AZIMUTH',
                              value: '${azimuth.toStringAsFixed(1)}°',
                              foot: compassDirection(azimuth),
                            ),
                          ),
                          Expanded(
                            child: _ValueBlock(
                              label: 'ALTITUDE',
                              value: formatAngle(altitude, signed: true),
                              foot: altitude.abs() < 2
                                  ? 'Near horizon'
                                  : 'Geometric, no refraction',
                            ),
                          ),
                        ],
                      ),
                      if (target.magnitude != null ||
                          solar?.position.visualMagnitude != null) ...[
                        const SizedBox(height: 18),
                        _ValueBlock(
                          label: 'APPARENT MAGNITUDE',
                          value:
                              (solar?.position.visualMagnitude ??
                                      target.magnitude!)
                                  .toStringAsFixed(2),
                          foot: 'Catalog/model value; visibility also depends on sky conditions',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (solar != null)
                  _SolarDetails(
                    body: target.solarBody!,
                    utc: snapshot.utc,
                    location: snapshot.location.latitudeDegrees,
                    longitude: snapshot.location.longitudeDegrees,
                    elevation: snapshot.location.elevationMeters,
                    illumination: solar.position.illuminatedFraction,
                    distanceAu: solar.position.distanceAu,
                  ),
                _DataCard(
                  ra: ra,
                  dec: dec,
                  target: target,
                  source: target.source,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Find in sky'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LocatorScreen(target: target),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera sky view'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CameraArScreen(target: target),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'The camera overlay uses an estimated field of view and phone sensors. It is an aiming aid, not a calibrated optical instrument.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFF8191A8)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SolarDetails extends StatelessWidget {
  const _SolarDetails({
    required this.body,
    required this.utc,
    required this.location,
    required this.longitude,
    required this.elevation,
    this.illumination,
    this.distanceAu,
  });

  final SolarBody body;
  final DateTime utc;
  final double location;
  final double longitude;
  final double elevation;
  final double? illumination;
  final double? distanceAu;

  @override
  Widget build(BuildContext context) {
    const engine = OfflineAstronomyEngine();
    final rise = engine.riseSet(
      body: body,
      rising: true,
      utcStart: utc,
      latitudeDegrees: location,
      longitudeDegrees: longitude,
      elevationMeters: elevation,
    );
    final set = engine.riseSet(
      body: body,
      rising: false,
      utcStart: utc,
      latitudeDegrees: location,
      longitudeDegrees: longitude,
      elevationMeters: elevation,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _DataCard(
        rows: [
          if (distanceAu != null) ('Distance', formatDistanceAu(distanceAu)),
          if (illumination != null && body != SolarBody.sun)
            (
              'Illuminated fraction',
              '${(illumination! * 100).toStringAsFixed(1)}%',
            ),
          (
            'Next rise',
            rise == null ? 'No rise in search interval' : localTimestamp(rise),
          ),
          (
            'Next set',
            set == null ? 'No set in search interval' : localTimestamp(set),
          ),
          ('Position model', 'Geocentric ephemeris, topocentric direction'),
        ],
        heading: 'Solar ephemeris',
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    this.heading = 'Catalog & ephemeris',
    this.ra,
    this.dec,
    this.target,
    this.source,
    this.rows = const [],
  });

  final String heading;
  final double? ra;
  final double? dec;
  final CelestialTarget? target;
  final String? source;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final details = <(String, String)>[
      if (ra != null) ('RA of date', formatRightAscension(ra!)),
      if (dec != null) ('Dec of date', formatDeclination(dec!)),
      if (target?.distanceLightYears != null)
        (
          'Distance',
          '${target!.distanceLightYears!.toStringAsFixed(1)} light-years',
        ),
      if (target?.constellation?.isNotEmpty == true)
        ('Constellation', target!.constellation!),
      if (target?.magnitudeBand != null && target?.magnitude != null)
        ('Magnitude source', '${target!.magnitudeBand} band'),
      if (source != null) ('Data source', source!),
      ...rows,
    ];
    if (details.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(heading),
            const SizedBox(height: 12),
            for (final (label, value) in details)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: const Color(0xFF95A6BF)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ValueBlock extends StatelessWidget {
  const _ValueBlock({required this.label, required this.value, this.foot});
  final String label;
  final String value;
  final String? foot;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(letterSpacing: 1, color: const Color(0xFF94A6C1)),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800, color: skyAccent),
      ),
      if (foot != null)
        Text(
          foot!,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: const Color(0xFF9AA8BD)),
        ),
    ],
  );
}

class _DetailNotice extends StatelessWidget {
  const _DetailNotice({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: skyGold),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(color: Color(0xFF9AA8BD), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

IconData _iconFor(String kind) {
  final value = kind.toLowerCase();
  if (value.contains('star') || value == 'sun') return Icons.auto_awesome;
  if (value.contains('galaxy')) return Icons.blur_circular;
  if (value.contains('black hole')) return Icons.brightness_7_outlined;
  if (value.contains('cluster')) return Icons.grain;
  if (value.contains('nebula')) return Icons.cloud_outlined;
  if (value.contains('planet')) return Icons.public;
  return Icons.stars;
}
