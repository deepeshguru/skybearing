import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/offline_sky_app.dart';
import '../app/providers.dart';
import '../core/models/observer_location.dart';

class LocationEditorSheet extends ConsumerStatefulWidget {
  const LocationEditorSheet({super.key});

  @override
  ConsumerState<LocationEditorSheet> createState() =>
      _LocationEditorSheetState();
}

class _LocationEditorSheetState extends ConsumerState<LocationEditorSheet> {
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _elevation;
  String? _validation;

  @override
  void initState() {
    super.initState();
    final location = ref.read(skyStateProvider).location;
    _latitude = TextEditingController(
      text: location?.latitudeDegrees.toString() ?? '',
    );
    _longitude = TextEditingController(
      text: location?.longitudeDegrees.toString() ?? '',
    );
    _elevation = TextEditingController(
      text: location?.elevationMeters.toStringAsFixed(0) ?? '0',
    );
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _elevation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(skyStateProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                'Observer location',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'GPS uses the phone’s GNSS receiver and can work without internet. You can also enter coordinates manually.',
                style: TextStyle(color: Color(0xFF9AA8BD), height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: state.isLocating
                    ? null
                    : () async {
                        await ref
                            .read(skyStateProvider.notifier)
                            .detectLocation();
                        if (!context.mounted) return;
                        if (ref.read(skyStateProvider).location?.source ==
                            LocationSource.gps) {
                          Navigator.of(context).pop();
                        }
                      },
                icon: state.isLocating
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  state.isLocating
                      ? 'Finding satellite fix…'
                      : 'Use current GPS location',
                ),
              ),
              if (state.locationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    state.locationMessage!,
                    style: const TextStyle(color: Color(0xFFFFC871)),
                  ),
                ),
              const SizedBox(height: 20),
              const Eyebrow('Manual coordinates'),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      _latitude,
                      'Latitude',
                      '-90 to 90°',
                      signed: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _numberField(
                      _longitude,
                      'Longitude',
                      '-180 to 180°',
                      signed: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              _numberField(
                _elevation,
                'Elevation',
                'meters above sea level',
                signed: true,
              ),
              const SizedBox(height: 5),
              Text(
                'Enter 0 m if elevation is unknown. Geometric horizon directions do not include atmospheric refraction.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFF8594AA)),
              ),
              if (_validation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _validation!,
                    style: const TextStyle(color: Color(0xFFFF8D8D)),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _saveManual,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save manual location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String hint, {
    bool signed = false,
  }) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        RegExp(signed ? r'^-?\d*\.?\d*$' : r'^\d*\.?\d*$'),
      ),
    ],
    decoration: InputDecoration(labelText: label, hintText: hint),
  );

  Future<void> _saveManual() async {
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    final elevation = double.tryParse(_elevation.text.trim());
    if (latitude == null || longitude == null || elevation == null) {
      setState(
        () => _validation =
            'Enter valid latitude, longitude, and elevation values.',
      );
      return;
    }
    try {
      await ref
          .read(skyStateProvider.notifier)
          .setManualLocation(
            latitudeDegrees: latitude,
            longitudeDegrees: longitude,
            elevationMeters: elevation,
          );
      if (mounted) Navigator.of(context).pop();
    } on FormatException catch (error) {
      setState(() => _validation = error.message);
    }
  }
}
