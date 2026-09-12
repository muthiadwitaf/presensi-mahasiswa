// Pure decision logic used by submit-attendance (and friends). Kept free of
// any Supabase/DB calls so it can be unit tested directly (see
// verification_test.ts) without spinning up a live backend.

export function haversineMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(a));
}

export interface GeofenceCheckInput {
  distanceM: number;
  radiusM: number;
  accuracyM: number | null | undefined;
  accuracyMaxM: number;
  isMocked: boolean | null | undefined;
}

export type GeofenceFailReason = "MOCK_LOCATION" | "LOW_ACCURACY" | "OUT_OF_RADIUS";

export interface GeofenceCheckResult {
  passed: boolean;
  reason?: GeofenceFailReason;
}

export function evaluateGeofence(input: GeofenceCheckInput): GeofenceCheckResult {
  if (input.isMocked) return { passed: false, reason: "MOCK_LOCATION" };
  if ((input.accuracyM ?? 0) > input.accuracyMaxM) return { passed: false, reason: "LOW_ACCURACY" };
  if (input.distanceM > input.radiusM) return { passed: false, reason: "OUT_OF_RADIUS" };
  return { passed: true };
}

export interface AttendanceWindowInput {
  nowMs: number;
  startsAtMs: number;
  opensAtMs: number;
  closesAtMs: number;
  lateThresholdMs: number;
}

export type AttendanceStatus = "HADIR" | "TERLAMBAT";

export interface AttendanceWindowResult {
  withinWindow: boolean;
  status: AttendanceStatus;
  minutesLate: number;
}

export function evaluateAttendanceWindow(input: AttendanceWindowInput): AttendanceWindowResult {
  const { nowMs, startsAtMs, opensAtMs, closesAtMs, lateThresholdMs } = input;
  return {
    withinWindow: nowMs >= opensAtMs && nowMs <= closesAtMs,
    status: nowMs > lateThresholdMs ? "TERLAMBAT" : "HADIR",
    minutesLate: Math.max(0, Math.round((nowMs - startsAtMs) / 60000)),
  };
}

export interface ChallengeRow {
  student_id: string;
  meeting_session_id: string;
  expires_at: string | number;
  consumed_at: string | number | null;
}

export type ChallengeFailReason = "NOT_FOUND" | "CONSUMED" | "EXPIRED" | "STUDENT_MISMATCH" | "SESSION_MISMATCH";

export interface ChallengeCheckResult {
  valid: boolean;
  reason?: ChallengeFailReason;
}

export function evaluateChallenge(
  challenge: ChallengeRow | null | undefined,
  nowMs: number,
  studentId: string,
  meetingSessionId: string,
): ChallengeCheckResult {
  if (!challenge) return { valid: false, reason: "NOT_FOUND" };
  if (challenge.consumed_at) return { valid: false, reason: "CONSUMED" };
  if (new Date(challenge.expires_at).getTime() < nowMs) return { valid: false, reason: "EXPIRED" };
  if (challenge.student_id !== studentId) return { valid: false, reason: "STUDENT_MISMATCH" };
  if (challenge.meeting_session_id !== meetingSessionId) return { valid: false, reason: "SESSION_MISMATCH" };
  return { valid: true };
}

export function euclideanDistance(a: number[], b: number[]): number {
  let sumSq = 0;
  for (let i = 0; i < a.length; i++) sumSq += (a[i] - b[i]) ** 2;
  return Math.sqrt(sumSq);
}

export function evaluateFaceMatch(distance: number, threshold: number): boolean {
  return distance <= threshold;
}

export function evaluateLiveness(
  score: number,
  threshold: number,
  realIsHighScore: boolean,
): { isReal: boolean; probReal: number } {
  const probReal = realIsHighScore ? score : 1 - score;
  return { isReal: probReal >= threshold, probReal };
}
