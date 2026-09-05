// The core server-side authority for attendance. The Flutter client sends
// EVIDENCE ONLY (never a status) — this function is the only writer of
// attendance_records.status. See plan doc §H / design doc §5.1 for the
// ordered validation steps this mirrors.
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { requireUser, serviceClient } from "../_shared/clients.ts";

function haversineMeters(lat1: number, lng1: number, lat2: number, lng2: number) {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(a));
}

async function settingNumber(admin: any, key: string, fallback: number) {
  const { data } = await admin.from("app_settings").select("value").eq("key", key).single();
  return data ? Number(data.value) : fallback;
}
async function settingBool(admin: any, key: string, fallback: boolean) {
  const { data } = await admin.from("app_settings").select("value").eq("key", key).single();
  return data ? Boolean(data.value) : fallback;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("METHOD_NOT_ALLOWED", "Use POST", 405);

  const started = Date.now();
  const admin = serviceClient();

  // Step 1: authenticated
  const auth = await requireUser(req);
  if ("error" in auth) return errorResponse("AUTH", auth.error, 401);

  const body = await req.json().catch(() => null);
  if (!body) return errorResponse("BAD_REQUEST", "Payload tidak valid", 400);

  const {
    meeting_session_id, course_class_id, session_date, challenge_nonce,
    face, liveness, location, device, client_processing_ms, experiment_tag,
  } = body;

  if (!face?.probe_embedding || !Array.isArray(face.probe_embedding) || face.probe_embedding.length !== 192) {
    return errorResponse("BAD_REQUEST", "probe_embedding harus 192 angka", 400);
  }
  if (typeof liveness?.score !== "number") {
    return errorResponse("BAD_REQUEST", "liveness.score wajib diisi", 400);
  }

  const logFail = (outcome: string, stage: string, reason: string, extra: Record<string, unknown> = {}) =>
    admin.rpc("log_failed_verification", {
      p_student_id: studentId ?? null,
      p_meeting_session_id: meeting_session_id ?? null,
      p_course_class_id: course_class_id ?? null,
      p_outcome: outcome,
      p_failure_stage: stage,
      p_failure_reason: reason,
      p_face_similarity: extra.faceSimilarity ?? null,
      p_anti_spoof_score: liveness?.score ?? null,
      p_gps_distance: extra.gpsDistance ?? null,
      p_verification_mode: verificationMode ?? "FACE_GPS",
      p_risk_score: extra.riskScore ?? 0,
      p_risk_flags: extra.riskFlags ?? [],
      p_client_reported_pass: face?.client_match ?? null,
      p_device_info: device ?? {},
      p_app_version: device?.app_version ?? null,
      p_model_versions: { antispoof: liveness?.model, face: face?.embedding_model },
      p_processing_ms: Date.now() - started,
      p_client_processing_ms: client_processing_ms ?? null,
      p_experiment_tag: experiment_tag ?? null,
    }).then(() => undefined);

  // Step 2: valid student — resolved from the JWT, never trusted from payload.
  const { data: student, error: studentErr } = await admin
    .from("students").select("id, academic_status").eq("user_id", auth.user.id).single();
  const studentId: string | null = student?.id ?? null;
  let verificationMode = "FACE_GPS";

  if (studentErr || !student || student.academic_status !== "AKTIF") {
    await logFail("ERROR", "AUTH", "Akun mahasiswa tidak valid/tidak aktif");
    return errorResponse("AUTH", "Akun mahasiswa tidak valid", 403);
  }

  // Step 3: session resolution (materialize from template if needed)
  let session;
  if (meeting_session_id) {
    const { data } = await admin.from("meeting_sessions").select("*").eq("id", meeting_session_id).single();
    session = data;
  } else if (course_class_id && session_date) {
    const { data: ensuredId } = await admin.rpc("ensure_session_for", {
      p_course_class_id: course_class_id, p_date: session_date,
    });
    if (ensuredId) {
      const { data } = await admin.from("meeting_sessions").select("*").eq("id", ensuredId).single();
      session = data;
    }
  }
  if (!session || session.status === "CANCELLED") {
    await logFail("FAIL_SESSION_CLOSED", "SESSION", "Sesi tidak ditemukan atau dibatalkan");
    return errorResponse("FAIL_SESSION_CLOSED", "Sesi presensi tidak ditemukan atau dibatalkan", 409);
  }
  const resolvedCourseClassId = session.course_class_id;

  // Step 4: enrolment
  const { data: enrollment } = await admin
    .from("enrollments").select("id")
    .eq("student_id", studentId).eq("course_class_id", resolvedCourseClassId).eq("status", "ACTIVE")
    .maybeSingle();
  if (!enrollment) {
    await logFail("FAIL_NOT_ENROLLED", "ENROLLMENT", "Mahasiswa tidak terdaftar KRS kelas ini");
    return errorResponse("FAIL_NOT_ENROLLED", "Anda tidak terdaftar pada kelas ini", 403);
  }

  // Step 5: session open
  if (!["SCHEDULED", "OPEN", "ONGOING"].includes(session.status)) {
    await logFail("FAIL_SESSION_CLOSED", "SESSION", "Sesi sudah ditutup");
    return errorResponse("FAIL_SESSION_CLOSED", "Sesi presensi sudah ditutup", 409);
  }

  // Step 6: timing window
  const openBefore = await settingNumber(admin, "checkin_open_before_minutes", 15);
  const closeAfter = await settingNumber(admin, "checkin_close_after_minutes", 30);
  const lateAfter = await settingNumber(admin, "late_after_minutes", 15);
  const startsAt = new Date(session.starts_at).getTime();
  const now = Date.now();
  const opensAt = session.checkin_opens_at ? new Date(session.checkin_opens_at).getTime() : startsAt - openBefore * 60000;
  const closesAt = session.checkin_closes_at ? new Date(session.checkin_closes_at).getTime() : startsAt + closeAfter * 60000;
  if (now < opensAt || now > closesAt) {
    await logFail("FAIL_WINDOW", "WINDOW", "Di luar jendela waktu presensi");
    return errorResponse("FAIL_WINDOW", "Presensi hanya bisa dilakukan pada jendela waktu yang ditentukan", 409);
  }
  const lateThresholdAt = session.late_threshold_at ? new Date(session.late_threshold_at).getTime() : startsAt + lateAfter * 60000;
  const minutesLate = Math.max(0, Math.round((now - startsAt) / 60000));
  const status = now > lateThresholdAt ? "TERLAMBAT" : "HADIR";

  // Step 7: challenge/nonce
  let challengeId: string | null = null;
  if (challenge_nonce) {
    const { data: challenge } = await admin
      .from("attendance_challenges").select("id, expires_at, consumed_at, student_id, meeting_session_id")
      .eq("nonce", challenge_nonce).maybeSingle();
    if (!challenge || challenge.consumed_at || new Date(challenge.expires_at).getTime() < now
        || challenge.student_id !== studentId || challenge.meeting_session_id !== session.id) {
      await logFail("FAIL_CHALLENGE", "CHALLENGE", "Nonce tidak valid/kedaluwarsa/sudah dipakai");
      return errorResponse("FAIL_CHALLENGE", "Sesi verifikasi kedaluwarsa, silakan ulangi", 409);
    }
    challengeId = challenge.id;
  }

  // Step 8: duplicate (soft check; DB unique constraint is the hard backstop)
  const { data: existing } = await admin
    .from("attendance_records").select("id").eq("student_id", studentId).eq("meeting_session_id", session.id).maybeSingle();
  if (existing) {
    await logFail("FAIL_DUPLICATE", "DUPLICATE", "Sudah presensi untuk sesi ini");
    return errorResponse("FAIL_DUPLICATE", "Anda sudah melakukan presensi untuk sesi ini", 409, { attendance_id: existing.id });
  }

  // Step 9: mode match
  verificationMode = session.mode === "ONLINE" ? "ONLINE_FACE" : "FACE_GPS";
  if (session.mode !== "ONLINE" && !location?.latitude) {
    await logFail("FAIL_MODE_MISMATCH", "MODE", "Sesi luring membutuhkan lokasi");
    return errorResponse("FAIL_MODE_MISMATCH", "Sesi ini membutuhkan lokasi GPS", 422);
  }

  // Step 10: geofence (only when enforced)
  let gpsDistance: number | null = null, geofenceRadius: number | null = null, geofenceSource = "SKIPPED";
  const bypassOnline = await settingBool(admin, "allow_online_geofence_bypass", true);
  const shouldGeofence = session.mode !== "ONLINE" || (!bypassOnline && location?.latitude);
  if (shouldGeofence && (session.require_geofence ?? true)) {
    const { data: geo } = await admin.rpc("resolve_geofence", { p_location_id: session.location_id });
    const g = Array.isArray(geo) ? geo[0] : geo;
    if (g?.enforced && location?.latitude != null) {
      gpsDistance = haversineMeters(location.latitude, location.longitude, g.lat, g.lng);
      geofenceRadius = g.radius_m;
      geofenceSource = g.source;
      const accuracyMax = await settingNumber(admin, "geofence_gps_accuracy_max_meters", 50);
      if (location.is_mocked || (location.accuracy_m ?? 0) > accuracyMax || gpsDistance > geofenceRadius) {
        await logFail("FAIL_GEOFENCE", "GEOFENCE",
          `Di luar area kelas (${Math.round(gpsDistance)}m dari radius ${geofenceRadius}m)`,
          { gpsDistance });
        return errorResponse("FAIL_GEOFENCE", "Anda berada di luar area kelas yang diizinkan", 422, {
          distance_m: Math.round(gpsDistance), allowed_m: geofenceRadius,
        });
      }
    }
  }

  // Step 11: anti-spoof
  const antiSpoofThreshold = await settingNumber(admin, "anti_spoof_threshold", 0.5);
  const realIsHigh = await settingBool(admin, "anti_spoof_real_is_high_score", true);
  const probReal = realIsHigh ? liveness.score : 1 - liveness.score;
  if (probReal < antiSpoofThreshold) {
    await logFail("FAIL_LIVENESS", "SPOOF", "Skor anti-spoof di bawah threshold");
    return errorResponse("FAIL_LIVENESS", "Sistem tidak dapat memastikan wajah asli", 422);
  }

  // Step 12: face match — server recomputes distance vs. the hidden reference embedding.
  const { data: faceProfile } = await admin
    .from("face_profiles").select("embedding, embedding_model").eq("student_id", studentId).eq("is_active", true).maybeSingle();
  if (!faceProfile) {
    await logFail("FAIL_NO_FACE_PROFILE", "FACE", "Wajah belum terdaftar");
    return errorResponse("FAIL_NO_FACE_PROFILE", "Wajah belum terdaftar, silakan daftarkan wajah terlebih dahulu", 422);
  }
  const ref: number[] = faceProfile.embedding;
  const probe: number[] = face.probe_embedding;
  let sumSq = 0;
  for (let i = 0; i < ref.length; i++) sumSq += (ref[i] - probe[i]) ** 2;
  const distance = Math.sqrt(sumSq);
  const faceThreshold = await settingNumber(admin, "face_match_threshold", 0.5);
  if (distance === 0) {
    await logFail("FAIL_FACE_MATCH", "FACE", "Jarak embedding persis 0 - dicurigai replay", { faceSimilarity: distance });
    return errorResponse("FAIL_FACE_MATCH", "Verifikasi wajah gagal", 422);
  }
  if (distance > faceThreshold) {
    await logFail("FAIL_FACE_MATCH", "FACE", "Wajah tidak cocok dengan data terdaftar", { faceSimilarity: distance });
    return errorResponse("FAIL_FACE_MATCH", "Wajah tidak cocok dengan data yang terdaftar", 422);
  }

  // Step 13: risk score (composite; informational unless above reject threshold)
  let riskScore = 0;
  const riskFlags: string[] = [];
  if (location?.is_mocked) { riskScore += 0.3; riskFlags.push("MOCK_LOCATION"); }
  if (device?.is_emulator) { riskScore += 0.2; riskFlags.push("EMULATOR"); }
  if (device?.is_rooted) { riskScore += 0.2; riskFlags.push("ROOTED"); }
  if ((location?.accuracy_m ?? 0) > 30) { riskScore += 0.1; riskFlags.push("LOW_GPS_ACCURACY"); }
  if (distance > faceThreshold * 0.9) { riskScore += 0.1; riskFlags.push("BORDERLINE_MATCH"); }
  riskScore = Math.min(1, riskScore);
  const rejectThreshold = await settingNumber(admin, "risk_reject_threshold", 0.85);
  if (riskScore >= rejectThreshold) {
    await logFail("ERROR", "RISK", "Risk score terlalu tinggi", { riskScore, riskFlags });
    return errorResponse("FAIL_RISK", "Presensi ditolak karena indikasi risiko tinggi, hubungi dosen/admin", 422);
  }

  // Commit — atomic insert of verification + attendance_records + challenge consumption.
  const { data: committed, error: commitErr } = await admin.rpc("commit_attendance", {
    p_student_id: studentId,
    p_meeting_session_id: session.id,
    p_enrollment_id: enrollment.id,
    p_course_class_id: resolvedCourseClassId,
    p_status: status,
    p_minutes_late: minutesLate,
    p_verification_mode: verificationMode,
    p_latitude: location?.latitude ?? null,
    p_longitude: location?.longitude ?? null,
    p_gps_accuracy_m: location?.accuracy_m ?? null,
    p_gps_distance: gpsDistance,
    p_geofence_radius_m: geofenceRadius,
    p_geofence_source: geofenceSource,
    p_face_similarity: distance,
    p_face_threshold: faceThreshold,
    p_anti_spoof_score: liveness.score,
    p_anti_spoof_threshold: antiSpoofThreshold,
    p_risk_score: riskScore,
    p_risk_flags: riskFlags,
    p_device_info: device ?? {},
    p_challenge_id: challengeId,
    p_app_version: device?.app_version ?? null,
    p_model_versions: { antispoof: liveness.model, face: face.embedding_model },
    p_client_processing_ms: client_processing_ms ?? null,
    p_processing_ms: Date.now() - started,
    p_experiment_tag: experiment_tag ?? null,
  });
  if (commitErr) return errorResponse("ERROR", commitErr.message, 500);

  const result = Array.isArray(committed) ? committed[0] : committed;
  return jsonResponse({
    success: true,
    attendance: {
      id: result.attendance_id,
      status,
      check_in_at: new Date().toISOString(),
      minutes_late: minutesLate,
      meeting_session_id: session.id,
    },
    verification: {
      id: result.verification_id,
      face_passed: true,
      anti_spoof_passed: true,
      geofence_passed: geofenceSource !== "SKIPPED" ? true : null,
      risk_level: riskScore >= 0.6 ? "MEDIUM" : "LOW",
    },
  });
});
