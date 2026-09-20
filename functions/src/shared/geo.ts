/** Straight-line miles between two WGS84 points. */
export function milesBetween(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const earthRadiusMiles = 3958.7613;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  return 2 * earthRadiusMiles * Math.asin(Math.min(1, Math.sqrt(a)));
}

/** City-speed ETA label matching Google-style strings (`5 mins`). */
export function formatDriverEta(miles: number): string {
  const avgCitySpeedMph = 20;
  const minutes = Math.max(1, Math.round((miles / avgCitySpeedMph) * 60));
  if (minutes < 60) {
    return minutes === 1 ? "1 min" : `${minutes} mins`;
  }
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  const hourLabel = hours === 1 ? "1 hour" : `${hours} hours`;
  if (remainder === 0) return hourLabel;
  const minLabel = remainder === 1 ? "1 min" : `${remainder} mins`;
  return `${hourLabel} ${minLabel}`;
}
