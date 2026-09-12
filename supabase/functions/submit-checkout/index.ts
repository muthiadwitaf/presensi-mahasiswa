import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { requireUser, serviceClient } from "../_shared/clients.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("METHOD_NOT_ALLOWED", "Use POST", 405);

  const auth = await requireUser(req);
  if ("error" in auth) return errorResponse("AUTH", auth.error, 401);

  const body = await req.json().catch(() => null);
  const { attendance_id, location } = body ?? {};
  if (!attendance_id) return errorResponse("BAD_REQUEST", "attendance_id wajib diisi", 400);

  const admin = serviceClient();
  const { data: student } = await admin.from("students").select("id").eq("user_id", auth.user.id).single();
  if (!student) return errorResponse("FORBIDDEN", "Akun mahasiswa tidak ditemukan", 403);

  const { data: record } = await admin
    .from("attendance_records").select("id, student_id, check_out_at, meeting_session_id")
    .eq("id", attendance_id).single();
  if (!record || record.student_id !== student.id) {
    return errorResponse("FORBIDDEN", "Data presensi tidak ditemukan", 403);
  }
  if (record.check_out_at) {
    return errorResponse("FAIL_DUPLICATE", "Sudah melakukan Clock Out", 409);
  }

  const { data: session } = await admin
    .from("meeting_sessions").select("ends_at, status").eq("id", record.meeting_session_id).single();
  if (session?.status === "CANCELLED") {
    return errorResponse("FAIL_SESSION_CLOSED", "Sesi sudah dibatalkan", 409);
  }

  const { error: updateErr } = await admin
    .from("attendance_records")
    .update({
      check_out_at: new Date().toISOString(),
      check_out_latitude: location?.latitude ?? null,
      check_out_longitude: location?.longitude ?? null,
    })
    .eq("id", attendance_id);
  if (updateErr) return errorResponse("ERROR", updateErr.message, 500);

  return jsonResponse({ success: true });
});
