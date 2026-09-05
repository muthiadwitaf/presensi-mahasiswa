-- Extensions
create extension if not exists pgcrypto;

-- Enum types
create type user_role         as enum ('mahasiswa','dosen','admin');
create type user_status       as enum ('pending','active','suspended','inactive');
create type delivery_mode     as enum ('ONLINE','OFFLINE','HYBRID');
create type session_status    as enum ('SCHEDULED','OPEN','ONGOING','CLOSED','CANCELLED','RESCHEDULED');
create type session_type      as enum ('REGULAR','MAKEUP','EXTRA','EXAM','FIELD');
create type attendance_status as enum ('HADIR','TERLAMBAT','IZIN','SAKIT','ALPA','DITOLAK');
create type verification_mode as enum ('FACE_GPS','FACE_ONLY','ONLINE_FACE','MANUAL_OVERRIDE','QR_FALLBACK');
create type verification_outcome as enum ('PASS','FAIL_LIVENESS','FAIL_FACE_MATCH','FAIL_GEOFENCE',
                                          'FAIL_WINDOW','FAIL_NOT_ENROLLED','FAIL_DUPLICATE',
                                          'FAIL_SESSION_CLOSED','FAIL_MODE_MISMATCH','FAIL_NO_FACE_PROFILE',
                                          'FAIL_CHALLENGE','ERROR');
create type enrollment_status as enum ('ACTIVE','DROPPED','COMPLETED');
create type leave_type        as enum ('IZIN','SAKIT','DISPENSASI');
create type leave_status      as enum ('PENDING','APPROVED','REJECTED','CANCELLED');
create type location_kind     as enum ('CAMPUS','BUILDING','ROOM','EXTERNAL');

create schema if not exists app;
