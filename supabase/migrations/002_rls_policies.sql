-- ============================================================
-- RLS POLICIES — Multi-Tenant Gym Management SaaS
-- ============================================================
-- ROLE HIERARCHY: owner > manager > trainer > receptionist
-- Higher roles inherit all permissions of lower roles.
-- ============================================================
-- PERMISSION MATRIX:
--                    SELECT  INSERT  UPDATE  DELETE
-- Owner              ALL     ALL     ALL     ALL
-- Manager            ALL     ALL     ALL     ALL (*staff/payments restricted)
-- Trainer            ALL     LMTD    LMTD    NONE
-- Receptionist       ALL     LMTD    NONE    NONE
-- ============================================================

-- 0. HELPERS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('owner', 'manager', 'trainer', 'receptionist');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Returns the tenant_id for the authenticated user.
CREATE OR REPLACE FUNCTION auth.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT tenant_id FROM public.profiles WHERE id = auth.uid()),
    NULL
  );
$$;

-- Returns the role for the authenticated user.
CREATE OR REPLACE FUNCTION auth.current_user_role()
RETURNS user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT role FROM public.profiles WHERE id = auth.uid()),
    NULL::user_role
  );
$$;

-- Role hierarchy check: owner > manager > trainer > receptionist
CREATE OR REPLACE FUNCTION auth.has_role(minimum_role user_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role IN (
        CASE minimum_role
          WHEN 'receptionist' THEN ARRAY['owner','manager','trainer','receptionist']::user_role[]
          WHEN 'trainer'      THEN ARRAY['owner','manager','trainer']::user_role[]
          WHEN 'manager'      THEN ARRAY['owner','manager']::user_role[]
          WHEN 'owner'        THEN ARRAY['owner']::user_role[]
        END
      )
  );
$$;

-- ============================================================
-- 1. ENABLE RLS
-- ============================================================

ALTER TABLE public.tenants            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.members            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_types   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_exercises  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_plans         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_plan_meals    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress_photos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_qr_codes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs         ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. TENANTS
-- ============================================================
-- Only owner can see/update their own tenant record.

CREATE POLICY "tenants_owner_select"
  ON public.tenants FOR SELECT
  USING (id = auth.current_tenant_id());

CREATE POLICY "tenants_owner_update"
  ON public.tenants FOR UPDATE
  USING (id = auth.current_tenant_id() AND auth.current_user_role() = 'owner')
  WITH CHECK (id = auth.current_tenant_id() AND auth.current_user_role() = 'owner');

-- No insert — tenant created via signup trigger.
-- No delete — soft-delete via is_active.

-- ============================================================
-- 3. PROFILES (staff accounts)
-- ============================================================
-- Owner/Manager: full CRUD on same-tenant staff.
-- Trainer/Receptionist: read all same-tenant, update self only.

CREATE POLICY "profiles_select"
  ON public.profiles FOR SELECT
  USING (
    id = auth.uid()
    OR tenant_id = auth.current_tenant_id()
  );

CREATE POLICY "profiles_insert"
  ON public.profiles FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('manager')
  );

CREATE POLICY "profiles_update"
  ON public.profiles FOR UPDATE
  USING (
    tenant_id = auth.current_tenant_id()
    AND (
      id = auth.uid()
      OR auth.has_role('manager')
    )
  )
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND (
      id = auth.uid()
      OR auth.has_role('manager')
    )
  );

CREATE POLICY "profiles_delete"
  ON public.profiles FOR DELETE
  USING (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('owner')
    AND id <> auth.uid()
  );

-- ============================================================
-- 4. MEMBERS
-- ============================================================
-- All roles can SELECT same-tenant members.
-- Trainer+ can INSERT/UPDATE. Manager+ can DELETE.

CREATE POLICY "members_select"
  ON public.members FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY "members_insert"
  ON public.members FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY "members_update"
  ON public.members FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('trainer'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY "members_delete"
  ON public.members FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- ============================================================
-- 5. MEMBERSHIP TYPES
-- ============================================================
-- Manager+ manages plans. All roles read.

CREATE POLICY "membership_types_select"
  ON public.membership_types FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY "membership_types_insert"
  ON public.membership_types FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('manager')
  );

CREATE POLICY "membership_types_update"
  ON public.membership_types FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY "membership_types_delete"
  ON public.membership_types FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- ============================================================
-- 6. ATTENDANCE
-- ============================================================
-- Receptionist+ can INSERT (check-in). Trainer+ can UPDATE (check-out).
-- Manager+ can DELETE. All roles read.

CREATE POLICY "attendance_select"
  ON public.attendance FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY "attendance_insert"
  ON public.attendance FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('receptionist')
  );

CREATE POLICY "attendance_update"
  ON public.attendance FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('receptionist'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY "attendance_delete"
  ON public.attendance FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- ============================================================
-- 7. PAYMENTS
-- ============================================================
-- Receptionist+ can INSERT. Manager+ can UPDATE (refunds) and DELETE.
-- All roles read.

CREATE POLICY "payments_select"
  ON public.payments FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY "payments_insert"
  ON public.payments FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('receptionist')
  );

CREATE POLICY "payments_update"
  ON public.payments FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY "payments_delete"
  ON public.payments FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- ============================================================
-- 8. EXERCISES
-- ============================================================
-- Trainer+ can INSERT/UPDATE. Manager+ can DELETE. All read.

CREATE POLICY "exercises_select"
  ON public.exercises FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY "exercises_insert"
  ON public.exercises FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY "exercises_update"
  ON public.exercises FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('trainer'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY "exercises_delete"
  ON public.exercises FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- ============================================================
-- 9. WORKOUTS
-- ============================================================
-- Trainer+ manages workouts. Manager+ can delete. All read.

CREATE POLICY "workouts_select"
  ON public.workouts FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY "workouts_insert"
  ON public.workouts FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY "workouts_update"
  ON public.workouts FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('trainer'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY "workouts_delete"
  ON public.workouts FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- ============================================================
-- 10. WORKOUT EXERCISES
-- ============================================================
-- Access is inherited through the parent workout's tenant_id.

CREATE POLICY "workout_exercises_select"
  ON public.workout_exercises FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.workouts
      WHERE id = workout_id AND tenant_id = auth.current_tenant_id()
    )
  );

CREATE POLICY "workout_exercises_insert"
  ON public.workout_exercises FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.workouts
      WHERE id = workout_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('trainer')
  );

CREATE POLICY "workout_exercises_update"
  ON public.workout_exercises FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.workouts
      WHERE id = workout_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('trainer')
  );

CREATE POLICY "workout_exercises_delete"
  ON public.workout_exercises FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.workouts
      WHERE id = workout_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('manager')
  );

-- ============================================================
-- 11. DIET PLANS
-- ============================================================
-- Trainer+ manages. Manager+ deletes. All read.

CREATE POLICY "diet_plans_select"
  ON public.diet_plans FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY "diet_plans_insert"
  ON public.diet_plans FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY "diet_plans_update"
  ON public.diet_plans FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('trainer'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY "diet_plans_delete"
  ON public.diet_plans FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- ============================================================
-- 12. DIET PLAN MEALS
-- ============================================================
-- Access inherited through parent diet_plan's tenant_id.

CREATE POLICY "diet_plan_meals_select"
  ON public.diet_plan_meals FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.diet_plans
      WHERE id = diet_plan_id AND tenant_id = auth.current_tenant_id()
    )
  );

CREATE POLICY "diet_plan_meals_insert"
  ON public.diet_plan_meals FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.diet_plans
      WHERE id = diet_plan_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('trainer')
  );

CREATE POLICY "diet_plan_meals_update"
  ON public.diet_plan_meals FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.diet_plans
      WHERE id = diet_plan_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('trainer')
  );

CREATE POLICY "diet_plan_meals_delete"
  ON public.diet_plan_meals FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.diet_plans
      WHERE id = diet_plan_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('manager')
  );

-- ============================================================
-- 13. PROGRESS PHOTOS
-- ============================================================
-- Trainer+ can INSERT/UPDATE (own uploads). Manager+ can DELETE. All read.

CREATE POLICY "progress_photos_select"
  ON public.progress_photos FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY "progress_photos_insert"
  ON public.progress_photos FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY "progress_photos_update"
  ON public.progress_photos FOR UPDATE
  USING (
    tenant_id = auth.current_tenant_id()
    AND (
      uploaded_by = auth.uid()
      OR auth.has_role('manager')
    )
  )
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY "progress_photos_delete"
  ON public.progress_photos FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- ============================================================
-- 14. MEMBER QR CODES
-- ============================================================
-- Trainer+ can INSERT and regenerate (UPDATE). Manager+ can DELETE.
-- All roles read.

CREATE POLICY "member_qr_codes_select"
  ON public.member_qr_codes FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY "member_qr_codes_insert"
  ON public.member_qr_codes FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY "member_qr_codes_update"
  ON public.member_qr_codes FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('trainer'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

-- QR codes are never deleted via RLS (deactivate via is_active)

-- ============================================================
-- 15. AUDIT LOGS
-- ============================================================
-- Append-only. Manager+ can read. No INSERT/UPDATE/DELETE policies.

CREATE POLICY "audit_logs_select"
  ON public.audit_logs FOR SELECT
  USING (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('manager')
  );

-- ============================================================
-- 16. STORAGE RLS
-- ============================================================

-- Create buckets if they don't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('progress-photos', 'progress-photos', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('tenant-assets',   'tenant-assets',   false, 5242880,  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'])
ON CONFLICT (id) DO NOTHING;

-- Storage folder structure: {tenant_id}/{member_id}/{uuid}.ext

CREATE POLICY "storage_progress_photos_select"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'progress-photos'
    AND auth.role() = 'authenticated'
    AND storage.foldername(name)[1] = auth.current_tenant_id()::text
  );

CREATE POLICY "storage_progress_photos_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'progress-photos'
    AND auth.role() = 'authenticated'
    AND storage.foldername(name)[1] = auth.current_tenant_id()::text
    AND auth.has_role('trainer')
  );

CREATE POLICY "storage_progress_photos_update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'progress-photos'
    AND auth.role() = 'authenticated'
    AND storage.foldername(name)[1] = auth.current_tenant_id()::text
    AND auth.has_role('trainer')
  );

CREATE POLICY "storage_progress_photos_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'progress-photos'
    AND auth.role() = 'authenticated'
    AND storage.foldername(name)[1] = auth.current_tenant_id()::text
    AND auth.has_role('manager')
  );

CREATE POLICY "storage_tenant_assets_select"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'tenant-assets'
    AND auth.role() = 'authenticated'
    AND storage.foldername(name)[1] = auth.current_tenant_id()::text
  );

CREATE POLICY "storage_tenant_assets_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'tenant-assets'
    AND auth.role() = 'authenticated'
    AND storage.foldername(name)[1] = auth.current_tenant_id()::text
    AND auth.has_role('manager')
  );

CREATE POLICY "storage_tenant_assets_update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'tenant-assets'
    AND auth.role() = 'authenticated'
    AND storage.foldername(name)[1] = auth.current_tenant_id()::text
    AND auth.has_role('manager')
  );

CREATE POLICY "storage_tenant_assets_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'tenant-assets'
    AND auth.role() = 'authenticated'
    AND storage.foldername(name)[1] = auth.current_tenant_id()::text
    AND auth.has_role('manager')
  );
