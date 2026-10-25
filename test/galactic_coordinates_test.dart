import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sky/core/astronomy/galactic_coordinates.dart';

void main() {
  test('maps the Galactic Center to the known J2000 equatorial direction', () {
    final center = galacticToEquatorialJ2000(
      longitudeDegrees: 0,
      latitudeDegrees: 0,
    );

    expect(center.rightAscensionHours, closeTo(17.7603, 0.0002));
    expect(center.declinationDegrees, closeTo(-28.9362, 0.0002));
  });

  test('maps the Galactic north pole to its J2000 reference coordinates', () {
    final pole = galacticToEquatorialJ2000(
      longitudeDegrees: 123,
      latitudeDegrees: 90,
    );

    expect(pole.rightAscensionHours, closeTo(12.8573, 0.0002));
    expect(pole.declinationDegrees, closeTo(27.1283, 0.0002));
  });

  test('generates the three five degree Milky Way band curves', () {
    final band = milkyWayBandJ2000();

    expect(band, hasLength(219));
    expect(
      band.first.rightAscensionHours,
      closeTo(band[72].rightAscensionHours, 1e-12),
    );
    expect(
      () => milkyWayBandJ2000(longitudeStepDegrees: 7),
      throwsFormatException,
    );
  });
}
