#ifndef OFFLINE_SKY_ASTRO_BRIDGE_H
#define OFFLINE_SKY_ASTRO_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

/* Output slots: RA hours, declination degrees, azimuth degrees, altitude
 * degrees, distance AU, visual magnitude, illuminated fraction, phase angle
 * degrees. Unsupported values are NaN. */
int offline_sky_body_position(
    int body_id, int year, int month, int day, int hour, int minute,
    double second, double latitude, double longitude, double elevation_m,
    double *output);

/* direction: +1 rise, -1 set. Returns UTC Unix seconds or NaN when there is
 * no event in the requested window. */
double offline_sky_rise_set(
    int body_id, int year, int month, int day, int hour, int minute,
    double second, double latitude, double longitude, double elevation_m,
    int direction, double limit_days);

/* J2000 catalog star/deep-sky point transformed to the local horizon. PMRA
 * follows the catalog convention mu_alpha*cos(dec), both motions in mas/year. */
int offline_sky_catalog_position(
    double ra_hours_j2000, double dec_deg_j2000,
    double pmra_masyr, double pmdec_masyr,
    int year, int month, int day, int hour, int minute, double second,
    double latitude, double longitude, double elevation_m,
    double *output);

/* Batched variant. catalog_data is count tuples of [RA hours, Dec degrees,
 * mu_alpha*cos(dec) mas/yr, mu_delta mas/yr]. output is count tuples of
 * [RA of date hours, Dec of date degrees, azimuth degrees, altitude degrees]. */
int offline_sky_catalog_positions(
    int count, const double *catalog_data,
    int year, int month, int day, int hour, int minute, double second,
    double latitude, double longitude, double elevation_m,
    double *output);

/* EQJ to local horizontal transform, for catalog coordinate tests. */
int offline_sky_j2000_to_horizon(
    double ra_hours_j2000, double dec_deg_j2000,
    int year, int month, int day, int hour, int minute, double second,
    double latitude, double longitude, double elevation_m,
    double *output);

#ifdef __cplusplus
}
#endif

#endif
