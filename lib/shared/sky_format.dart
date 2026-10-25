import 'dart:math' as math;

String formatAngle(double value, {int decimals = 1, bool signed = false}) {
  final prefix = signed && value > 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(decimals)}°';
}

String formatRightAscension(double hours) {
  final totalSeconds = ((hours % 24 + 24) % 24 * 3600).round();
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
}

String formatDeclination(double degrees) {
  final sign = degrees < 0 ? '−' : '+';
  final absolute = degrees.abs();
  final d = absolute.floor();
  final minutes = ((absolute - d) * 60).floor();
  final seconds = (((absolute - d) * 60 - minutes) * 60).round();
  return '$sign${d.toString().padLeft(2, '0')}° ${minutes.toString().padLeft(2, '0')}′ ${seconds.toString().padLeft(2, '0')}″';
}

String compassDirection(double azimuth) {
  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return directions[((azimuth % 360 + 360) % 360 / 45).round() % 8];
}

String formatDistanceAu(double? au) {
  if (au == null || !au.isFinite) return 'Not available';
  if (au < 0.01) return '${(au * 149597870.7).round()} km';
  if (au < 10) return '${au.toStringAsFixed(3)} AU';
  return '${au.toStringAsFixed(2)} AU';
}

String localTimestamp(DateTime utc) {
  final local = utc.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} · $hour:$minute $period';
}

double radians(double degrees) => degrees * math.pi / 180;
