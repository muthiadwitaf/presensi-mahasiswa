// Integration test for the presensi backend (item #12: full flow) and the
// negative-case matrix (item #13).
//
// HOW TO RUN (requires a local Supabase stack — NOT runnable in this
// sandbox, no Deno CLI or local Supabase instance is available here; this
// file is written and reviewed for correctness but has not been executed):
//
//   supabase start
//   # supabase start prints "API URL", "anon key", "service_role key" — export them:
//   export SUPABASE_URL="http://127.0.0.1:54321"
//   export SUPABASE_ANON_KEY="<anon key from supabase start>"
//   export SUPABASE_SERVICE_ROLE_KEY="<service_role key from supabase start>"
//   deno test --allow-net --allow-env supabase/tests/attendance_flow_test.ts
//
// Each test builds its own fixtures (faculty/program/course/class/session/
// student/face profile) directly via the service-role client rather than
// through the app's signup/enrollment UI, so tests don't depend on each
// other or on seed data. There is no teardown — re-running against the
// same local stack will hit unique-constraint collisions (nim/username/
// code), so run `supabase db reset` between runs.
//
// Scope: this exercises everything from "student authenticates" through
// "submit-attendance returns pass/fail" — auth, enrollment, session
// window, challenge/nonce, geofence, liveness threshold, face-match
// threshold, duplicate detection. It does NOT exercise the on-device
// camera/ML Kit/TFLite pipeline (face detection, liveness inference, face
// embedding extraction) — those need a real device; here they're
// simulated with the same synthetic embeddings/scores the client would
// send after running inference locally. "Tidak ada wajah" and "Dua wajah"
// from the negative-case list are NOT covered here because they are
// entirely client-side gates (PresensiProvider.processFrame) that never
// produce an HTTP request at all — see test/face_quality_service_test.dart
// and the `faces.length` checks instead.

import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CAN_RUN = Boolean(ANON_KEY && SERVICE_ROLE_KEY);

if (!CAN_RUN) {
  console.warn(
    "SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY not set - all tests in " +
      "attendance_flow_test.ts will be skipped. Run `supabase start` and export the printed keys first.",
  );
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY || "placeholder", { auth: { persistSession: false } });

const REFERENCE_EMBEDDING = Array.from({ length: 192 }, (_, i) => Math.sin(i));
const DIFFERENT_PERSON_EMBEDDING = Array.from({ length: 192 }, (_, i) => Math.cos(i * 3));

const CAMPUS = { lat: -6.302, lng: 106.652 };
function offsetMeters(lat: number, lng: number, metersNorth: number) {
  return { lat: lat + metersNorth / 111_320, lng };
}
function goodLocation() {
  return { latitude: CAMPUS.lat, longitude: CAMPUS.lng, accuracy_m: 10, is_mocked: false };
}

interface Fixture {
  studentEmail: string;
  studentPassword: string;
  studentId: string;
  courseClassId: string;
  locationId: string;
}

async function buildBaseFixture(suffix: string): Promise<Fixture> {
  const s = suffix.replace(/[^a-zA-Z0-9]/g, "").slice(0, 16) || "x";
  const email = `test-student-${s}@example.test`;
  const password = "Test1234!";

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email, password, email_confirm: true,
  });
  if (createErr) throw createErr;
  const authId = created.user!.id;

  const { error: userErr } = await admin.from("users").insert({
    id: authId, username: `student_${s}`, full_name: `Test Student ${s}`, role: "mahasiswa",
  });
  if (userErr) throw userErr;

  const { data: faculty, error: facultyErr } = await admin
    .from("faculties").insert({ code: `FAC_${s}`, name: `Fakultas Test ${s}` }).select("id").single();
  if (facultyErr) throw facultyErr;

  const { data: prodi, error: prodiErr } = await admin
    .from("study_programs").insert({ faculty_id: faculty!.id, code: `PRD_${s}`, name: `Prodi Test ${s}` })
    .select("id").single();
  if (prodiErr) throw prodiErr;

  const { data: student, error: studentErr } = await admin.from("students").insert({
    user_id: authId, nim: `NIM${s}`, full_name: `Test Student ${s}`,
    study_program_id: prodi!.id, entry_year: 2023, academic_status: "AKTIF",
  }).select("id").single();
  if (studentErr) throw studentErr;

  const { data: term, error: termErr } = await admin.from("academic_terms").insert({
    code: `TERM_${s}`, academic_year: "2025/2026", semester_type: "GANJIL",
    start_date: "2025-08-01", end_date: "2026-01-31",
  }).select("id").single();
  if (termErr) throw termErr;

  const { data: location, error: locationErr } = await admin.from("locations").insert({
    code: `LOC_${s}`, name: `Ruang Test ${s}`, kind: "ROOM",
    latitude: CAMPUS.lat, longitude: CAMPUS.lng, radius_meters: 100, is_geofenced: true,
  }).select("id").single();
  if (locationErr) throw locationErr;

  const { data: course, error: courseErr } = await admin.from("courses").insert({
    study_program_id: prodi!.id, code: `MK_${s}`, name: `Mata Kuliah Test ${s}`, credits: 3,
  }).select("id").single();
  if (courseErr) throw courseErr;

  const { data: courseClass, error: classErr } = await admin.from("course_classes").insert({
    course_id: course!.id, academic_term_id: term!.id, code: `KLS_${s}`,
  }).select("id").single();
  if (classErr) throw classErr;

  const { error: enrollErr } = await admin.from("enrollments").insert({
    student_id: student!.id, course_class_id: courseClass!.id, status: "ACTIVE",
  });
  if (enrollErr) throw enrollErr;

  const { error: faceErr } = await admin.from("face_profiles").insert({
    student_id: student!.id, embedding: REFERENCE_EMBEDDING,
  });
  if (faceErr) throw faceErr;

  return {
    studentEmail: email, studentPassword: password,
    studentId: student!.id, courseClassId: courseClass!.id, locationId: location!.id,
  };
}

async function createSession(fixture: Fixture, opts: {
  mode?: "OFFLINE" | "ONLINE";
  status?: string;
  checkinOffsetMinutes?: [number, number]; // [minutes window opened before now, minutes window closes after now]
  lateAfterMinutes?: number;
  requireGeofence?: boolean;
  locationId?: string | null;
}): Promise<{ id: string }> {
  const now = new Date();
  const sessionDate = now.toISOString().slice(0, 10);
  const startTime = now.toISOString().slice(11, 19);
  const endTime = new Date(now.getTime() + 2 * 3600_000).toISOString().slice(11, 19);

  const [opensBefore, closesAfter] = opts.checkinOffsetMinutes ?? [15, 30];
  const checkinOpensAt = new Date(now.getTime() - opensBefore * 60_000).toISOString();
  const checkinClosesAt = new Date(now.getTime() + closesAfter * 60_000).toISOString();
  const lateThresholdAt = new Date(now.getTime() + (opts.lateAfterMinutes ?? 15) * 60_000).toISOString();
  const mode = opts.mode ?? "OFFLINE";

  const { data: session, error } = await admin.from("meeting_sessions").insert({
    course_class_id: fixture.courseClassId,
    session_date: sessionDate, start_time: startTime, end_time: endTime,
    mode,
    location_id: mode === "ONLINE" ? null : (opts.locationId === undefined ? fixture.locationId : opts.locationId),
    meeting_url: mode === "ONLINE" ? "https://meet.example.test/x" : null,
    status: opts.status ?? "OPEN",
    checkin_opens_at: checkinOpensAt, checkin_closes_at: checkinClosesAt,
    late_threshold_at: lateThresholdAt,
    require_geofence: opts.requireGeofence,
  }).select("id").single();
  if (error) throw error;
  return { id: session!.id };
}

async function studentClient(fixture: Fixture): Promise<SupabaseClient> {
  const client = createClient(SUPABASE_URL, ANON_KEY);
  const { error } = await client.auth.signInWithPassword({
    email: fixture.studentEmail, password: fixture.studentPassword,
  });
  if (error) throw error;
  return client;
}

// deno-lint-ignore no-explicit-any
async function requestChallenge(client: SupabaseClient, meetingSessionId: string): Promise<any> {
  const { data } = await client.functions.invoke("attendance-challenge", {
    body: { meeting_session_id: meetingSessionId },
  });
  return data;
}

// deno-lint-ignore no-explicit-any
async function submit(client: SupabaseClient, body: Record<string, unknown>): Promise<{ data: any; status: number }> {
  const { data, error } = await client.functions.invoke("submit-attendance", { body });
  // supabase-js surfaces non-2xx as `error` with the body on error.context; normalize both shapes.
  if (error) {
    const context = (error as { context?: Response }).context;
    const body = context ? await context.json().catch(() => null) : null;
    return { data: body, status: context?.status ?? 500 };
  }
  return { data, status: 200 };
}

// --- Happy path (item #12: full flow) ---

Deno.test({
  name: "full flow: login -> challenge -> face+liveness (simulated) -> geofence -> submit -> PASS",
  ignore: !CAN_RUN,
  fn: async () => {
    const fixture = await buildBaseFixture("happy");
    const session = await createSession(fixture, {});
    const client = await studentClient(fixture);

    const challenge = await requestChallenge(client, session.id);
    assertExists(challenge?.challenge?.nonce);

    // Same embedding for stored profile and probe -> distance exactly 0.
    // Under the old (removed) `distance === 0` "replay" heuristic this
    // would have been wrongly rejected as FAIL_FACE_MATCH; this asserts
    // that bug stays fixed.
    const { data, status } = await submit(client, {
      meeting_session_id: session.id,
      challenge_nonce: challenge.challenge.nonce,
      face: { probe_embedding: REFERENCE_EMBEDDING, embedding_model: "mobilefacenet-v1" },
      liveness: { score: 0.95, model: "mobilenetv2-antispoof" },
      location: goodLocation(),
    });

    assertEquals(status, 200);
    assertEquals(data.success, true);
    assertEquals(data.attendance.status, "HADIR");
  },
});

// --- Negative test matrix (item #13) ---
//
// | Skenario                          | Expected            |
// |------------------------------------|---------------------|
// | Wajah orang lain                   | FAIL_FACE_MATCH     |
// | Foto HP / cetak / video            | FAIL_LIVENESS       |
// | Di luar geofence                   | FAIL_GEOFENCE       |
// | GPS tidak akurat                   | FAIL_GEOFENCE       |
// | Mock location                      | FAIL_GEOFENCE       |
// | Di luar jam presensi               | FAIL_WINDOW         |
// | Nonce kedaluwarsa/tidak ditemukan  | FAIL_CHALLENGE      |
// | Presensi dua kali                  | FAIL_DUPLICATE      |
//
// Note on "Foto HP / cetak / video": the backend only ever sees a single
// liveness score number from the client's on-device MobileNetV2 inference —
// it cannot distinguish which spoof medium produced a low score. All three
// collapse to the same server-side test case here. Telling them apart is a
// model-accuracy question for item #2 (dataset-based threshold
// calibration), not something an HTTP integration test can exercise.

interface NegativeCase {
  name: string;
  expectedCode: string;
  buildSession: (fixture: Fixture) => Promise<string>;
  request: (sessionId: string, nonce: string) => Record<string, unknown>;
}

const negativeCases: NegativeCase[] = [
  {
    name: "wajah orang lain",
    expectedCode: "FAIL_FACE_MATCH",
    buildSession: async (f) => (await createSession(f, {})).id,
    request: (sessionId, nonce) => ({
      meeting_session_id: sessionId, challenge_nonce: nonce,
      face: { probe_embedding: DIFFERENT_PERSON_EMBEDDING, embedding_model: "mobilefacenet-v1" },
      liveness: { score: 0.95 }, location: goodLocation(),
    }),
  },
  {
    name: "foto HP / cetak / video (skor liveness rendah)",
    expectedCode: "FAIL_LIVENESS",
    buildSession: async (f) => (await createSession(f, {})).id,
    request: (sessionId, nonce) => ({
      meeting_session_id: sessionId, challenge_nonce: nonce,
      face: { probe_embedding: REFERENCE_EMBEDDING, embedding_model: "mobilefacenet-v1" },
      liveness: { score: 0.1 }, location: goodLocation(),
    }),
  },
  {
    name: "di luar geofence",
    expectedCode: "FAIL_GEOFENCE",
    buildSession: async (f) => (await createSession(f, {})).id,
    request: (sessionId, nonce) => ({
      meeting_session_id: sessionId, challenge_nonce: nonce,
      face: { probe_embedding: REFERENCE_EMBEDDING, embedding_model: "mobilefacenet-v1" },
      liveness: { score: 0.95 },
      location: { ...offsetMeters(CAMPUS.lat, CAMPUS.lng, 500), accuracy_m: 10, is_mocked: false },
    }),
  },
  {
    name: "GPS tidak akurat",
    expectedCode: "FAIL_GEOFENCE",
    buildSession: async (f) => (await createSession(f, {})).id,
    request: (sessionId, nonce) => ({
      meeting_session_id: sessionId, challenge_nonce: nonce,
      face: { probe_embedding: REFERENCE_EMBEDDING, embedding_model: "mobilefacenet-v1" },
      liveness: { score: 0.95 },
      location: { latitude: CAMPUS.lat, longitude: CAMPUS.lng, accuracy_m: 999, is_mocked: false },
    }),
  },
  {
    name: "mock location",
    expectedCode: "FAIL_GEOFENCE",
    buildSession: async (f) => (await createSession(f, {})).id,
    request: (sessionId, nonce) => ({
      meeting_session_id: sessionId, challenge_nonce: nonce,
      face: { probe_embedding: REFERENCE_EMBEDDING, embedding_model: "mobilefacenet-v1" },
      liveness: { score: 0.95 },
      location: { latitude: CAMPUS.lat, longitude: CAMPUS.lng, accuracy_m: 10, is_mocked: true },
    }),
  },
  {
    name: "di luar jam presensi",
    expectedCode: "FAIL_WINDOW",
    buildSession: async (f) => (await createSession(f, { checkinOffsetMinutes: [120, -60] })).id,
    request: (sessionId, nonce) => ({
      meeting_session_id: sessionId, challenge_nonce: nonce,
      face: { probe_embedding: REFERENCE_EMBEDDING, embedding_model: "mobilefacenet-v1" },
      liveness: { score: 0.95 }, location: goodLocation(),
    }),
  },
  {
    name: "nonce tidak ditemukan/kedaluwarsa",
    expectedCode: "FAIL_CHALLENGE",
    buildSession: async (f) => (await createSession(f, {})).id,
    request: (sessionId, _nonce) => ({
      meeting_session_id: sessionId, challenge_nonce: "nonexistent.nonce-value",
      face: { probe_embedding: REFERENCE_EMBEDDING, embedding_model: "mobilefacenet-v1" },
      liveness: { score: 0.95 }, location: goodLocation(),
    }),
  },
];

for (const testCase of negativeCases) {
  Deno.test({
    name: `negative case: ${testCase.name} -> ${testCase.expectedCode}`,
    ignore: !CAN_RUN,
    fn: async () => {
      const fixture = await buildBaseFixture(testCase.name);
      const sessionId = await testCase.buildSession(fixture);
      const client = await studentClient(fixture);
      const challenge = await requestChallenge(client, sessionId);
      const nonce = challenge?.challenge?.nonce ?? "";
      const { data, status } = await submit(client, testCase.request(sessionId, nonce));
      assertEquals(data?.success, false);
      assertEquals(data?.error?.code, testCase.expectedCode);
      assertEquals(status >= 400, true);
    },
  });
}

Deno.test({
  name: "negative case: presensi dua kali -> FAIL_DUPLICATE",
  ignore: !CAN_RUN,
  fn: async () => {
    const fixture = await buildBaseFixture("duplicate");
    const session = await createSession(fixture, {});
    const client = await studentClient(fixture);

    const challenge1 = await requestChallenge(client, session.id);
    const first = await submit(client, {
      meeting_session_id: session.id, challenge_nonce: challenge1.challenge.nonce,
      face: { probe_embedding: REFERENCE_EMBEDDING, embedding_model: "mobilefacenet-v1" },
      liveness: { score: 0.95 }, location: goodLocation(),
    });
    assertEquals(first.data.success, true);

    const challenge2 = await requestChallenge(client, session.id);
    const second = await submit(client, {
      meeting_session_id: session.id, challenge_nonce: challenge2.challenge.nonce,
      face: { probe_embedding: REFERENCE_EMBEDDING, embedding_model: "mobilefacenet-v1" },
      liveness: { score: 0.95 }, location: goodLocation(),
    });
    assertEquals(second.data.success, false);
    assertEquals(second.data.error.code, "FAIL_DUPLICATE");
  },
});
