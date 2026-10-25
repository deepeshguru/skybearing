#include "astro_bridge.h"
#include "upstream/astronomy.h"

#include <math.h>

#define SKY_PI 3.14159265358979323846264338327950288

enum {
    OUT_RA_HOURS = 0,
    OUT_DEC_DEGREES = 1,
    OUT_AZIMUTH_DEGREES = 2,
    OUT_ALTITUDE_DEGREES = 3,
    OUT_DISTANCE_AU = 4,
    OUT_MAGNITUDE = 5,
    OUT_ILLUMINATED_FRACTION = 6,
    OUT_PHASE_ANGLE_DEGREES = 7,
    OUTPUT_COUNT = 8
};

static astro_body_t map_body(int id)
{
    switch (id) {
        case 0: return BODY_SUN;
        case 1: return BODY_MOON;
        case 2: return BODY_MERCURY;
        case 3: return BODY_VENUS;
        case 4: return BODY_MARS;
        case 5: return BODY_JUPITER;
        case 6: return BODY_SATURN;
        case 7: return BODY_URANUS;
        case 8: return BODY_NEPTUNE;
        case 9: return BODY_PLUTO;
        default: return BODY_INVALID;
    }
}

static int valid_observer(double latitude, double longitude, double elevation_m)
{
    return isfinite(latitude) && isfinite(longitude) && isfinite(elevation_m) &&
           latitude >= -90.0 && latitude <= 90.0 &&
           longitude >= -180.0 && longitude <= 180.0 && elevation_m >= -500.0;
}

static int valid_datetime(int year, int month, int day, int hour, int minute, double second)
{
    static const int month_days[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    int leap;
    int max_day;
    if (year < 1 || year > 9999 || month < 1 || month > 12 ||
        hour < 0 || hour > 23 || minute < 0 || minute > 59 ||
        !isfinite(second) || second < 0.0 || second >= 60.0)
        return 0;
    leap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
    max_day = month_days[month - 1] + (month == 2 && leap ? 1 : 0);
    return day >= 1 && day <= max_day;
}

static astro_time_t make_time(int year, int month, int day, int hour, int minute, double second)
{
    return Astronomy_MakeTime(year, month, day, hour, minute, second);
}

int offline_sky_body_position(
    int body_id, int year, int month, int day, int hour, int minute,
    double second, double latitude, double longitude, double elevation_m,
    double *output)
{
    int i;
    astro_body_t body = map_body(body_id);
    astro_time_t time;
    astro_observer_t observer;
    astro_equatorial_t equ;
    astro_horizon_t hor;
    astro_illum_t illum;
    astro_angle_result_t phase;

    if (output == NULL) return ASTRO_INVALID_PARAMETER;
    for (i = 0; i < OUTPUT_COUNT; ++i) output[i] = NAN;
    if (body == BODY_INVALID || !valid_datetime(year, month, day, hour, minute, second) ||
        !valid_observer(latitude, longitude, elevation_m))
        return ASTRO_INVALID_PARAMETER;

    time = make_time(year, month, day, hour, minute, second);
    observer = Astronomy_MakeObserver(latitude, longitude, elevation_m);
    equ = Astronomy_Equator(body, &time, observer, EQUATOR_OF_DATE, ABERRATION);
    if (equ.status != ASTRO_SUCCESS) return equ.status;
    hor = Astronomy_Horizon(&time, observer, equ.ra, equ.dec, REFRACTION_NONE);

    output[OUT_RA_HOURS] = equ.ra;
    output[OUT_DEC_DEGREES] = equ.dec;
    output[OUT_AZIMUTH_DEGREES] = hor.azimuth;
    output[OUT_ALTITUDE_DEGREES] = hor.altitude;
    output[OUT_DISTANCE_AU] = equ.dist;
    output[OUT_ILLUMINATED_FRACTION] = body == BODY_SUN ? 1.0 : NAN;
    output[OUT_PHASE_ANGLE_DEGREES] = NAN;

    illum = Astronomy_Illumination(body, time);
    if (illum.status == ASTRO_SUCCESS) {
        output[OUT_MAGNITUDE] = illum.mag;
        output[OUT_ILLUMINATED_FRACTION] = illum.phase_fraction;
        output[OUT_PHASE_ANGLE_DEGREES] = illum.phase_angle;
    }
    if (body == BODY_MOON) {
        phase = Astronomy_MoonPhase(time);
        if (phase.status == ASTRO_SUCCESS) output[OUT_PHASE_ANGLE_DEGREES] = phase.angle;
    }
    return ASTRO_SUCCESS;
}

double offline_sky_rise_set(
    int body_id, int year, int month, int day, int hour, int minute,
    double second, double latitude, double longitude, double elevation_m,
    int direction, double limit_days)
{
    astro_body_t body = map_body(body_id);
    astro_time_t time;
    astro_observer_t observer;
    astro_search_result_t result;

    if (body == BODY_INVALID || direction == 0 || !isfinite(limit_days) ||
        limit_days == 0.0 || !valid_observer(latitude, longitude, elevation_m))
        return NAN;
    if (!valid_datetime(year, month, day, hour, minute, second)) return NAN;
    time = make_time(year, month, day, hour, minute, second);
    observer = Astronomy_MakeObserver(latitude, longitude, elevation_m);
    result = Astronomy_SearchRiseSetEx(
        body, observer, direction > 0 ? DIRECTION_RISE : DIRECTION_SET,
        time, limit_days, 0.0);
    if (result.status != ASTRO_SUCCESS) return NAN;
    /* Astronomy Engine's UT day zero is 2000-01-01 12:00 UTC. */
    return 946728000.0 + result.time.ut * 86400.0;
}

int offline_sky_catalog_positions(
    int count, const double *catalog_data,
    int year, int month, int day, int hour, int minute, double second,
    double latitude, double longitude, double elevation_m, double *output)
{
    int index;
    astro_time_t time;
    astro_observer_t observer;
    astro_rotation_t to_horizon;
    astro_rotation_t to_equator_of_date;
    double years;
    const double mas_to_rad = SKY_PI / (180.0 * 3600000.0);

    if (count < 0 || count > 1000000 || (count > 0 && (catalog_data == NULL || output == NULL)) ||
        !valid_datetime(year, month, day, hour, minute, second) ||
        !valid_observer(latitude, longitude, elevation_m))
        return ASTRO_INVALID_PARAMETER;

    time = make_time(year, month, day, hour, minute, second);
    observer = Astronomy_MakeObserver(latitude, longitude, elevation_m);
    to_horizon = Astronomy_Rotation_EQJ_HOR(&time, observer);
    if (to_horizon.status != ASTRO_SUCCESS) return to_horizon.status;
    to_equator_of_date = Astronomy_Rotation_EQJ_EQD(&time);
    if (to_equator_of_date.status != ASTRO_SUCCESS) return to_equator_of_date.status;
    years = time.tt / 365.25;

    for (index = 0; index < count; ++index) {
        const double *input = catalog_data + 4 * index;
        double *result = output + 4 * index;
        double ra = input[0];
        double dec = input[1];
        double pmra = input[2];
        double pmdec = input[3];
        double alpha, delta, ca, sa, cd, sd, x, y, z, length;
        astro_spherical_t sphere;
        astro_vector_t eqj, horizontal, of_date;
        astro_spherical_t hor;
        astro_equatorial_t equatorial;

        if (!isfinite(ra) || !isfinite(dec) || !isfinite(pmra) || !isfinite(pmdec) ||
            ra < 0.0 || ra >= 24.0 || dec < -90.0 || dec > 90.0)
            return ASTRO_INVALID_PARAMETER;

        alpha = ra * (15.0 * SKY_PI / 180.0);
        delta = dec * (SKY_PI / 180.0);
        ca = cos(alpha); sa = sin(alpha); cd = cos(delta); sd = sin(delta);
        x = cd * ca; y = cd * sa; z = sd;
        /* HYG reports mu_alpha*cos(dec), so propagate in the local tangent plane. */
        x += years * mas_to_rad * (-pmra * sa - pmdec * ca * sd);
        y += years * mas_to_rad * ( pmra * ca - pmdec * sa * sd);
        z += years * mas_to_rad * ( pmdec * cd);
        length = sqrt(x*x + y*y + z*z);
        if (!isfinite(length) || length == 0.0) return ASTRO_BAD_VECTOR;
        sphere.status = ASTRO_SUCCESS;
        sphere.lat = asin(z / length) * 180.0 / SKY_PI;
        sphere.lon = atan2(y, x) * 180.0 / SKY_PI;
        if (sphere.lon < 0.0) sphere.lon += 360.0;
        sphere.dist = 1.0;
        eqj = Astronomy_VectorFromSphere(sphere, time);
        if (eqj.status != ASTRO_SUCCESS) return eqj.status;
        horizontal = Astronomy_RotateVector(to_horizon, eqj);
        if (horizontal.status != ASTRO_SUCCESS) return horizontal.status;
        hor = Astronomy_HorizonFromVector(horizontal, REFRACTION_NONE);
        if (hor.status != ASTRO_SUCCESS) return hor.status;
        of_date = Astronomy_RotateVector(to_equator_of_date, eqj);
        if (of_date.status != ASTRO_SUCCESS) return of_date.status;
        equatorial = Astronomy_EquatorFromVector(of_date);
        if (equatorial.status != ASTRO_SUCCESS) return equatorial.status;

        result[0] = equatorial.ra;
        result[1] = equatorial.dec;
        result[2] = hor.lon;
        result[3] = hor.lat;
    }
    return ASTRO_SUCCESS;
}

static int catalog_position(
    double ra_hours_j2000, double dec_deg_j2000,
    double pmra_masyr, double pmdec_masyr,
    int year, int month, int day, int hour, int minute, double second,
    double latitude, double longitude, double elevation_m, double *output)
{
    int i;
    double input[4] = { ra_hours_j2000, dec_deg_j2000, pmra_masyr, pmdec_masyr };
    double result[4];
    int status;
    if (output == NULL) return ASTRO_INVALID_PARAMETER;
    for (i = 0; i < OUTPUT_COUNT; ++i) output[i] = NAN;
    status = offline_sky_catalog_positions(1, input, year, month, day, hour, minute,
        second, latitude, longitude, elevation_m, result);
    if (status != ASTRO_SUCCESS) return status;
    for (i = 0; i < 4; ++i) output[i] = result[i];
    return ASTRO_SUCCESS;
}

int offline_sky_catalog_position(
    double ra_hours_j2000, double dec_deg_j2000,
    double pmra_masyr, double pmdec_masyr,
    int year, int month, int day, int hour, int minute, double second,
    double latitude, double longitude, double elevation_m, double *output)
{
    return catalog_position(ra_hours_j2000, dec_deg_j2000,
        pmra_masyr, pmdec_masyr, year, month, day, hour, minute, second,
        latitude, longitude, elevation_m, output);
}

int offline_sky_j2000_to_horizon(
    double ra_hours_j2000, double dec_deg_j2000,
    int year, int month, int day, int hour, int minute, double second,
    double latitude, double longitude, double elevation_m, double *output)
{
    return catalog_position(ra_hours_j2000, dec_deg_j2000, 0.0, 0.0,
        year, month, day, hour, minute, second,
        latitude, longitude, elevation_m, output);
}
