import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { requireUser, serviceClient } from "../_shared/clients.ts";
import { settingNumber } from "../_shared/settings.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("METHOD_NOT_ALLOWED", "Use POST", 405);

  const auth = await requireUser(req);
  if ("error" in auth) return errorResponse("AUTH", auth.error, 401);

  const body = await req.json().catch(() => null);
  const courseClassId = body?.course_class_id as string | undefined;
  const sessionDate = body?.session_date as string | undefined;
  let meetingSessionId = body?.meeting_session_id as string | undefined;
  if (!meetingSessionId && !(courseClassId && sessionDate)) {
    return errorResponse("BAD_REQUEST", "meeting_session_id atau course_class_id+session_date wajib diisi", 400);
  }

  const admin = serviceClient();

  const { data: student, error: studentErr } = await admin
    .from("students").select("id").eq("user_id", auth.user.id).single();
  if (studentErr || !student) return errorResponse("FORBIDDEN", "Akun mahasiswa tidak ditemukan", 403);

  if (!meetingSessionId) {
    const { data: ensuredId } = await admin.rpc("ensure_session_for", {
      p_course_class_id: courseClassId, p_date: sessionDate,
    });
    if (!ensuredId) return errorResponse("FAIL_SESSION_CLOSED", "Sesi presensi tidak ditemukan", 409);
    meetingSessionId = ensuredId;
  }

  const ttlSeconds = await settingNumber(admin, "max_challenge_ttl_seconds", 120);

  const nonce = crypto.randomUUID() + "." + crypto.randomUUID();
  const expiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString();

  const { data: challenge, error: insertErr } = await admin
    .from("attendance_challenges")
    .insert({
      student_id: student.id,
      meeting_session_id: meetingSessionId,
      nonce,
      expires_at: expiresAt,
      client_ip: req.headers.get("x-forwarded-for"),
    })
    .select("nonce, expires_at")
    .single();
  if (insertErr) return errorResponse("ERROR", insertErr.message, 500);

  return jsonResponse({
    success: true,
    challenge: { ...challenge, meeting_session_id: meetingSessionId },
  });
});
