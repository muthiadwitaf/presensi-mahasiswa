// Student/lecturer self-activation: they provide their username + the
// activation code an admin handed them + a password of their choice. Role
// comes ONLY from the matching provisioned_accounts row — there is no role
// field in this request at all.
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/clients.ts";

async function sha256(text: string) {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// ".local" ditolak Supabase Auth (email_address_invalid - bukan TLD publik
// yang dikenali), diverifikasi langsung lewat /auth/v1/signup.
const AUTH_DOMAIN = "smartattendance.app";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("METHOD_NOT_ALLOWED", "Use POST", 405);

  const body = await req.json().catch(() => null);
  const { username, activation_code, password } = body ?? {};
  if (!username || !activation_code || !password) {
    return errorResponse("BAD_REQUEST", "username, activation_code, password wajib diisi", 400);
  }
  if (password.length < 8) {
    return errorResponse("BAD_REQUEST", "Password minimal 8 karakter", 400);
  }

  const admin = serviceClient();
  const { data: pa, error: paErr } = await admin
    .from("provisioned_accounts").select("*")
    .eq("username", username).is("claimed_at", null).maybeSingle();
  if (paErr || !pa) return errorResponse("NOT_PROVISIONED", "Akun belum di-provisioning admin", 404);
  if (new Date(pa.expires_at).getTime() < Date.now()) {
    return errorResponse("EXPIRED", "Kode aktivasi sudah kedaluwarsa, hubungi admin", 410);
  }
  const codeHash = await sha256(activation_code.toUpperCase());
  if (codeHash !== pa.activation_code_hash) {
    return errorResponse("INVALID_CODE", "Kode aktivasi salah", 401);
  }

  const email = `${username}@${AUTH_DOMAIN}`;
  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email, password, email_confirm: true,
    app_metadata: { role: pa.role },
    user_metadata: { full_name: pa.full_name },
  });
  if (createErr || !created.user) {
    return errorResponse("ERROR", createErr?.message ?? "Gagal membuat akun", 500);
  }

  // The on_auth_user_created trigger inserts `public.users` and marks
  // provisioned_accounts as claimed. We only need the role-specific child row.
  if (pa.role === "mahasiswa") {
    await admin.from("students").insert({
      user_id: created.user.id,
      nim: pa.nim ?? username,
      full_name: pa.full_name,
      study_program_id: pa.study_program_id,
      class_group_id: pa.class_group_id,
      entry_year: new Date().getFullYear(),
    });
  } else if (pa.role === "dosen") {
    await admin.from("lecturers").insert({
      user_id: created.user.id,
      nip: pa.nip ?? username,
      full_name: pa.full_name,
      study_program_id: pa.study_program_id,
    });
  }

  return jsonResponse({ success: true, message: "Akun berhasil diaktifkan, silakan login" });
});
