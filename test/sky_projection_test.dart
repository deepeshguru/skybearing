import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sky/core/rendering/sky_projection.dart';

void main() {
  const size = Size(400, 400);

  test('maps the view center to the center of the canvas', () {
    final projection = SkyProjection(
      centerAzimuthDegrees: 180,
      centerAltitudeDegrees: 35,
      fieldOfViewDegrees: 100,
    );

    expect(projection.project(180, 35, size), const Offset(200, 200));
  });

  test('projects increasing azimuth to screen right', () {
    final projection = SkyProjection(
      centerAzimuthDegrees: 0,
      centerAltitudeDegrees: 45,
      fieldOfViewDegrees: 100,
    );

    final east = projection.project(15, 45, size)!;
    final west = projection.project(345, 45, size)!;
    expect(east.dx, greaterThan(size.width / 2));
    expect(west.dx, lessThan(size.width / 2));
  });

  test('rejects directions behind the view plane', () {
    final projection = SkyProjection(
      centerAzimuthDegrees: 0,
      centerAltitudeDegrees: 45,
      fieldOfViewDegrees: 100,
    );

    expect(projection.project(180, 45, size), isNull);
  });

  test('shows more stars as the field of view narrows', () {
    expect(starMagnitudeLimitForFieldOfView(150), closeTo(4.2, 1e-12));
    expect(starMagnitudeLimitForFieldOfView(75), closeTo(5.425, 1e-12));
    expect(starMagnitudeLimitForFieldOfView(32), closeTo(6.5, 1e-12));
  });
}
