import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { requireUser, serviceClient } from "../_shared/clients.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("METHOD_NOT_ALLOWED", "Use POST", 405);

  const auth = await requireUser(req);
  if ("error" in auth) return errorResponse("AUTH", auth.error, 401);

  const body = await req.json().catch(() => null);
  const { probe_embedding, embedding_model, quality_score, photo_base64 } = body ?? {};
  if (!Array.isArray(probe_embedding) || probe_embedding.length !== 192) {
    return errorResponse("BAD_REQUEST", "probe_embedding harus 192 angka", 400);
  }

  const admin = serviceClient();
  const { data: student } = await admin.from("students").select("id").eq("user_id", auth.user.id).single();
  if (!student) return errorResponse("AUTH", "Akun mahasiswa tidak ditemukan", 403);

  const { data: minQuality } = await admin.from("app_settings").select("value").eq("key", "face_enroll_min_quality").single();
  if (typeof quality_score === "number" && quality_score < Number(minQuality?.value ?? 0.5)) {
    return errorResponse("QUALITY_TOO_LOW", "Kualitas foto wajah terlalu rendah, coba lagi dengan pencahayaan lebih baik", 422);
  }

  const { data: cooldownSetting } = await admin.from("app_settings").select("value").eq("key", "face_enroll_cooldown_hours").single();
  const cooldownHours = Number(cooldownSetting?.value ?? 24);
  const { data: existing } = await admin
    .from("face_profiles").select("id, embedding, updated_at, version").eq("student_id", student.id).maybeSingle();
  if (existing) {
    const hoursSince = (Date.now() - new Date(existing.updated_at).getTime()) / 3600000;
    if (hoursSince < cooldownHours) {
      return errorResponse("COOLDOWN", `Pendaftaran ulang wajah baru bisa dilakukan lagi setelah ${Math.ceil(cooldownHours - hoursSince)} jam`, 429);
    }
  }

  let photoPath: string | null = null;
  if (photo_base64) {
    const bytes = Uint8Array.from(atob(photo_base64), (c) => c.charCodeAt(0));
    photoPath = `${student.id}/v${(existing?.version ?? 0) + 1}.jpg`;
    const { error: uploadErr } = await admin.storage.from("face-photos").upload(photoPath, bytes, {
      contentType: "image/jpeg", upsert: true,
    });
    if (uploadErr) return errorResponse("ERROR", uploadErr.message, 500);
  }

  if (existing) {
    await admin.from("face_profile_history").insert({
      student_id: student.id, version: existing.version, embedding: existing.embedding,
      replaced_by: auth.user.id, reason: "Pendaftaran ulang wajah",
    });
  }

  const { error: upsertErr } = await admin.from("face_profiles").upsert({
    student_id: student.id,
    embedding: probe_embedding,
    embedding_dim: probe_embedding.length,
    embedding_model: embedding_model ?? "mobilefacenet-v1",
    photo_path: photoPath,
    quality_score: quality_score ?? null,
    updated_at: new Date().toISOString(),
    updated_by: auth.user.id,
    version: (existing?.version ?? 0) + 1,
    is_active: true,
  }, { onConflict: "student_id" });
  if (upsertErr) return errorResponse("ERROR", upsertErr.message, 500);

  return jsonResponse({ success: true });
});
