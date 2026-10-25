import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/offline_sky_app.dart';
import '../../app/providers.dart';
import '../../core/models/device_orientation.dart';
import '../../shared/location_editor.dart';
import '../../shared/sky_format.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(skyStateProvider);
    final orientation = ref.watch(orientationProvider);
    final fov = ref.watch(cameraVerticalFovProvider);
    final location = state.location;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 15),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Personalize your observing setup'),
                  const SizedBox(height: 5),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverList.list(
              children: [
                _SettingsCard(
                  title: 'Observer location',
                  icon: Icons.location_on_outlined,
                  subtitle: location == null
                      ? 'No saved position'
                      : '${location.latitudeDegrees.toStringAsFixed(4)}°, ${location.longitudeDegrees.toStringAsFixed(4)}° · ${location.elevationMeters.round()} m',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (location?.horizontalAccuracyMeters != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Text(
                            'Last reported GPS accuracy ±${location!.horizontalAccuracyMeters!.round()} m. GPS needs sky visibility; a cold start may take longer.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF93A2B8)),
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final detectButton = OutlinedButton.icon(
                            onPressed: state.isLocating
                                ? null
                                : () => ref
                                      .read(skyStateProvider.notifier)
                                      .detectLocation(),
                            icon: state.isLocating
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            label: const Text('Detect GPS'),
                          );
                          final manualButton = FilledButton.tonalIcon(
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => const LocationEditorSheet(),
                            ),
                            icon: const Icon(Icons.edit_location_alt_outlined),
                            label: const Text('Edit manually'),
                          );
                          if (constraints.maxWidth < 280) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                detectButton,
                                const SizedBox(height: 8),
                                manualButton,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: detectButton),
                              const SizedBox(width: 9),
                              Expanded(child: manualButton),
                            ],
                          );
                        },
                      ),
                      if (state.locationMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: Text(
                            state.locationMessage!,
                            style: const TextStyle(color: Color(0xFFFFC871)),
                          ),
                        ),
                    ],
                  ),
                ),
                _SettingsCard(
                  title: 'Observation time',
                  icon: Icons.schedule,
                  subtitle:
                      '${state.liveTime ? 'Live local time' : 'Selected time'} · ${localTimestamp(state.currentTime.toUtc())}',
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _chooseDateTime(context, ref, state.currentTime),
                          icon: const Icon(Icons.edit_calendar_outlined),
                          label: const Text('Choose date & time'),
                        ),
                      ),
                      if (!state.liveTime) ...[
                        const SizedBox(width: 9),
                        IconButton.filledTonal(
                          onPressed: () =>
                              ref.read(skyStateProvider.notifier).setNow(),
                          tooltip: 'Return to now',
                          icon: const Icon(Icons.update),
                        ),
                      ],
                    ],
                  ),
                ),
                _SettingsCard(
                  title: 'Phone orientation',
                  icon: Icons.screen_rotation_outlined,
                  subtitle: orientation.when(
                    data: (value) => _sensorStatus(value),
                    loading: () => 'Waiting for motion sensors',
                    error: (_, _) => 'Sensor stream unavailable',
                  ),
                  child: orientation.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text(
                      'The device did not provide an orientation stream: $error',
                      style: const TextStyle(color: Color(0xFFFFC871)),
                    ),
                    data: (value) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            InfoChip(
                              icon: Icons.explore,
                              label: value.northReference.name,
                            ),
                            InfoChip(
                              icon: Icons.sensors,
                              label: value.quality.name,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Hold the phone upright and move it slowly in a figure eight if the compass direction appears unstable. Metal, magnets, vehicle dashboards, and nearby electronics can disturb the magnetometer. Sensor confidence is separate from ephemeris accuracy.',
                          style: TextStyle(
                            color: Color(0xFF93A2B8),
                            height: 1.4,
                          ),
                        ),
                        if (value.headingAccuracyDegrees != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              'Estimated heading uncertainty ±${value.headingAccuracyDegrees!.toStringAsFixed(0)}°',
                              style: const TextStyle(color: Color(0xFFB7C3D7)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _SettingsCard(
                  title: 'Camera overlay calibration',
                  icon: Icons.camera_alt_outlined,
                  subtitle: 'Approximate vertical field of view',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Vertical field of view')),
                          Text(
                            '${fov.round()}°',
                            style: const TextStyle(
                              color: skyAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: fov,
                        min: 35,
                        max: 70,
                        divisions: 35,
                        label: '${fov.round()}°',
                        onChanged: (value) => ref
                            .read(cameraVerticalFovProvider.notifier)
                            .setDegrees(value),
                      ),
                      const Text(
                        'Adjust until the AR guide matches the camera view on your device. The value is saved locally; lens distortion, camera cropping, and sensor alignment still affect overlay placement.',
                        style: TextStyle(color: Color(0xFF93A2B8), height: 1.4),
                      ),
                    ],
                  ),
                ),
                const _SettingsCard(
                  title: 'Offline data & privacy',
                  icon: Icons.wifi_off,
                  subtitle: 'Astronomy calculations and catalogs are bundled on this device.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DataBullet(
                        'No backend, login, network astronomy service, or runtime catalog download.',
                      ),
                      _DataBullet(
                        'GNSS positioning can work offline when satellites are visible; network-based location is not required.',
                      ),
                      _DataBullet(
                        'Star data: HYG Database v4.1 · CC BY-SA 4.0.',
                      ),
                      _DataBullet(
                        'Deep-sky catalog: OpenNGC 2026-05-01 · CC BY-SA 4.0.',
                      ),
                      _DataBullet(
                        '88 constellation patterns: Stellarium modern sky culture · CC BY-SA 4.0.',
                      ),
                      _DataBullet(
                        'Astronomy Engine 2.1.19 · MIT; notice bundled on this device.',
                      ),
                      _DataBullet(
                        'Black-hole source locations and Milky Way center: selected SIMBAD records · ODbL 1.0 · Wenger et al. 2000, A&AS 143, 9. The sky marker shows the source/system position, not a resolved event horizon.',
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Full source pins and license notices are included in the project documentation and bundled license folder.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF93A2B8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseDateTime(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
    final local = current.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      helpText: 'Choose observation date',
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final IconData icon;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: skyAccent.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: skyAccent, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: const Color(0xFF91A1B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _DataBullet extends StatelessWidget {
  const _DataBullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 5, color: skyAccent),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFCDD6E4),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

String _sensorStatus(DeviceOrientation value) {
  if (!value.isAvailable) return 'Orientation stream is currently unavailable';
  final north = value.northReference == NorthReference.trueNorth
      ? 'true north'
      : value.northReference == NorthReference.magneticNorth
      ? 'magnetic north'
      : 'unknown north reference';
  return '${value.quality.name} confidence · $north';
}
