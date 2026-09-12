// Unit tests for the pure decision logic in verification.ts.
// Run with: deno test supabase/functions/_shared/verification_test.ts
// (requires the Deno CLI; the Supabase CLI bundles one under
// `supabase functions` tooling, or install from https://deno.com)

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  euclideanDistance,
  evaluateAttendanceWindow,
  evaluateChallenge,
  evaluateFaceMatch,
  evaluateGeofence,
  evaluateLiveness,
  haversineMeters,
} from "./verification.ts";

// --- Haversine distance ---

Deno.test("haversineMeters: same point is zero distance", () => {
  assertEquals(haversineMeters(-6.302, 106.652, -6.302, 106.652), 0);
});

Deno.test("haversineMeters: ~111km per degree of latitude at the equator-ish scale", () => {
  const d = haversineMeters(0, 0, 1, 0);
  assertEquals(Math.round(d / 1000), 111);
});

Deno.test("haversineMeters: known short distance (~56m, campus-scale)", () => {
  const d = haversineMeters(-6.302, 106.652, -6.3025, 106.652);
  assertEquals(d > 50 && d < 60, true);
});

// --- Geofence validation ---

Deno.test("evaluateGeofence: passes when within radius, accurate, not mocked", () => {
  const r = evaluateGeofence({ distanceM: 100, radiusM: 150, accuracyM: 20, accuracyMaxM: 50, isMocked: false });
  assertEquals(r, { passed: true });
});

Deno.test("evaluateGeofence: fails exactly at the radius boundary + 1", () => {
  const r = evaluateGeofence({ distanceM: 150.01, radiusM: 150, accuracyM: 10, accuracyMaxM: 50, isMocked: false });
  assertEquals(r.passed, false);
  assertEquals(r.reason, "OUT_OF_RADIUS");
});

Deno.test("evaluateGeofence: passes exactly at the radius boundary", () => {
  const r = evaluateGeofence({ distanceM: 150, radiusM: 150, accuracyM: 10, accuracyMaxM: 50, isMocked: false });
  assertEquals(r.passed, true);
});

Deno.test("evaluateGeofence: rejects mock location even if within radius", () => {
  const r = evaluateGeofence({ distanceM: 10, radiusM: 150, accuracyM: 10, accuracyMaxM: 50, isMocked: true });
  assertEquals(r, { passed: false, reason: "MOCK_LOCATION" });
});

Deno.test("evaluateGeofence: rejects poor GPS accuracy even if within radius", () => {
  const r = evaluateGeofence({ distanceM: 10, radiusM: 150, accuracyM: 80, accuracyMaxM: 50, isMocked: false });
  assertEquals(r, { passed: false, reason: "LOW_ACCURACY" });
});

Deno.test("evaluateGeofence: missing accuracy treated as 0 (does not fail accuracy check)", () => {
  const r = evaluateGeofence({ distanceM: 10, radiusM: 150, accuracyM: null, accuracyMaxM: 50, isMocked: false });
  assertEquals(r.passed, true);
});

// --- Face match (euclidean distance / threshold) ---

Deno.test("euclideanDistance: identical embeddings are zero distance", () => {
  assertEquals(euclideanDistance([1, 2, 3], [1, 2, 3]), 0);
});

Deno.test("euclideanDistance: matches known 3-4-5 triangle", () => {
  assertEquals(euclideanDistance([0, 0], [3, 4]), 5);
});

Deno.test("evaluateFaceMatch: at-threshold distance matches (inclusive)", () => {
  assertEquals(evaluateFaceMatch(0.5, 0.5), true);
});

Deno.test("evaluateFaceMatch: just-over-threshold distance rejects", () => {
  assertEquals(evaluateFaceMatch(0.51, 0.5), false);
});

// --- Liveness threshold decision ---

Deno.test("evaluateLiveness: realIsHighScore=true, score above threshold is real", () => {
  const r = evaluateLiveness(0.8, 0.5, true);
  assertEquals(r.isReal, true);
  assertEquals(r.probReal, 0.8);
});

Deno.test("evaluateLiveness: realIsHighScore=true, score below threshold is spoof", () => {
  const r = evaluateLiveness(0.3, 0.5, true);
  assertEquals(r.isReal, false);
});

Deno.test("evaluateLiveness: realIsHighScore=false inverts the score", () => {
  // raw score 0.2 with realIsHighScore=false -> probReal = 0.8 -> real
  const r = evaluateLiveness(0.2, 0.5, false);
  assertEquals(r.isReal, true);
  assertEquals(r.probReal, 0.8);
});

Deno.test("evaluateLiveness: boundary score exactly at threshold passes (inclusive)", () => {
  const r = evaluateLiveness(0.5, 0.5, true);
  assertEquals(r.isReal, true);
});

// --- Attendance window / lateness ---

const MIN = 60_000;

Deno.test("evaluateAttendanceWindow: before opening is outside window", () => {
  const startsAt = 1_000_000;
  const r = evaluateAttendanceWindow({
    nowMs: startsAt - 20 * MIN, startsAtMs: startsAt,
    opensAtMs: startsAt - 15 * MIN, closesAtMs: startsAt + 30 * MIN, lateThresholdMs: startsAt + 15 * MIN,
  });
  assertEquals(r.withinWindow, false);
});

Deno.test("evaluateAttendanceWindow: after closing is outside window", () => {
  const startsAt = 1_000_000;
  const r = evaluateAttendanceWindow({
    nowMs: startsAt + 31 * MIN, startsAtMs: startsAt,
    opensAtMs: startsAt - 15 * MIN, closesAtMs: startsAt + 30 * MIN, lateThresholdMs: startsAt + 15 * MIN,
  });
  assertEquals(r.withinWindow, false);
});

Deno.test("evaluateAttendanceWindow: on time (before late threshold) is HADIR", () => {
  const startsAt = 1_000_000;
  const r = evaluateAttendanceWindow({
    nowMs: startsAt, startsAtMs: startsAt,
    opensAtMs: startsAt - 15 * MIN, closesAtMs: startsAt + 30 * MIN, lateThresholdMs: startsAt + 15 * MIN,
  });
  assertEquals(r.withinWindow, true);
  assertEquals(r.status, "HADIR");
  assertEquals(r.minutesLate, 0);
});

Deno.test("evaluateAttendanceWindow: after late threshold but before close is TERLAMBAT", () => {
  const startsAt = 1_000_000;
  const r = evaluateAttendanceWindow({
    nowMs: startsAt + 20 * MIN, startsAtMs: startsAt,
    opensAtMs: startsAt - 15 * MIN, closesAtMs: startsAt + 30 * MIN, lateThresholdMs: startsAt + 15 * MIN,
  });
  assertEquals(r.withinWindow, true);
  assertEquals(r.status, "TERLAMBAT");
  assertEquals(r.minutesLate, 20);
});

// --- Challenge (nonce) expiration/single-use/binding ---

const student = "student-1";
const meetingSession = "session-1";
const now = 2_000_000;

Deno.test("evaluateChallenge: missing challenge is invalid", () => {
  const r = evaluateChallenge(null, now, student, meetingSession);
  assertEquals(r, { valid: false, reason: "NOT_FOUND" });
});

Deno.test("evaluateChallenge: valid, unconsumed, unexpired, matching student+session passes", () => {
  const r = evaluateChallenge(
    { student_id: student, meeting_session_id: meetingSession, expires_at: now + 60_000, consumed_at: null },
    now, student, meetingSession,
  );
  assertEquals(r, { valid: true });
});

Deno.test("evaluateChallenge: already-consumed nonce is rejected (single-use)", () => {
  const r = evaluateChallenge(
    { student_id: student, meeting_session_id: meetingSession, expires_at: now + 60_000, consumed_at: now - 1000 },
    now, student, meetingSession,
  );
  assertEquals(r, { valid: false, reason: "CONSUMED" });
});

Deno.test("evaluateChallenge: expired nonce is rejected", () => {
  const r = evaluateChallenge(
    { student_id: student, meeting_session_id: meetingSession, expires_at: now - 1000, consumed_at: null },
    now, student, meetingSession,
  );
  assertEquals(r, { valid: false, reason: "EXPIRED" });
});

Deno.test("evaluateChallenge: nonce issued to a different student is rejected", () => {
  const r = evaluateChallenge(
    { student_id: "someone-else", meeting_session_id: meetingSession, expires_at: now + 60_000, consumed_at: null },
    now, student, meetingSession,
  );
  assertEquals(r, { valid: false, reason: "STUDENT_MISMATCH" });
});

Deno.test("evaluateChallenge: nonce issued for a different session is rejected", () => {
  const r = evaluateChallenge(
    { student_id: student, meeting_session_id: "other-session", expires_at: now + 60_000, consumed_at: null },
    now, student, meetingSession,
  );
  assertEquals(r, { valid: false, reason: "SESSION_MISMATCH" });
});
