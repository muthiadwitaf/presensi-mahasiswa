// Admin creates a provisioned-account entry (username + role decided server
// side) and an activation code. The student/lecturer later calls
// activate-account with that code to set their own password — they never
// choose their own role.
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { requireUser, serviceClient } from "../_shared/clients.ts";

function randomActivationCode() {
  return Math.random().toString(36).slice(2, 8).toUpperCase();
}
async function sha256(text: string) {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("METHOD_NOT_ALLOWED", "Use POST", 405);

  const auth = await requireUser(req);
  if ("error" in auth) return errorResponse("AUTH", auth.error, 401);

  const admin = serviceClient();
  const { data: caller } = await admin.from("users").select("role").eq("id", auth.user.id).single();
  if (caller?.role !== "admin") return errorResponse("FORBIDDEN", "Hanya admin yang dapat provisioning akun", 403);

  const body = await req.json().catch(() => null);
  const { username, full_name, role, study_program_id, class_group_id, nim, nip } = body ?? {};
  if (!username || !full_name || !role) {
    return errorResponse("BAD_REQUEST", "username, full_name, role wajib diisi", 400);
  }
  if (!["mahasiswa", "dosen", "admin"].includes(role)) {
    return errorResponse("BAD_REQUEST", "role tidak valid", 400);
  }

  const activationCode = randomActivationCode();
  const activationCodeHash = await sha256(activationCode);
  const expiresAt = new Date(Date.now() + 14 * 24 * 3600 * 1000).toISOString();

  const { error: insertErr } = await admin.from("provisioned_accounts").insert({
    username, full_name, role,
    study_program_id: study_program_id ?? null,
    class_group_id: class_group_id ?? null,
    nim: nim ?? null, nip: nip ?? null,
    activation_code_hash: activationCodeHash,
    expires_at: expiresAt,
    created_by: auth.user.id,
  });
  if (insertErr) return errorResponse("ERROR", insertErr.message, 500);

  await admin.from("audit_logs").insert({
    actor_id: auth.user.id, actor_role: "admin", action: "PROVISION_ACCOUNT",
    entity_type: "provisioned_accounts", after_data: { username, role },
  });

  return jsonResponse({
    success: true,
    provisioning: { username, activation_code: activationCode, expires_at: expiresAt },
  });
});
