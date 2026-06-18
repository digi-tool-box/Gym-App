-- ============================================================
-- COMPLETE SUPABASE SCHEMA — Multi-Tenant Gym Management SaaS
-- ============================================================
-- Run order: this single file is idempotent when run as a migration.
-- ============================================================

-- 0. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pgjwt";

-- 1. ENUMS
-- ============================================================
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('owner', 'manager', 'trainer', 'receptionist');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE member_status AS ENUM ('active', 'frozen', 'expired', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE payment_method AS ENUM ('cash', 'card', 'upi', 'bank_transfer');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE check_in_method AS ENUM ('qr', 'manual', 'receptionist');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE workout_status AS ENUM ('scheduled', 'in_progress', 'completed', 'missed');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE subscription_status AS ENUM ('active', 'trialing', 'past_due', 'canceled', 'incomplete');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE photo_type AS ENUM ('front', 'back', 'side', 'custom');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE muscle_group AS ENUM (
    'chest', 'back', 'shoulders', 'biceps', 'triceps', 'forearms',
    'quadriceps', 'hamstrings', 'glutes', 'calves', 'abs', 'core',
    'full_body', 'cardio', 'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. AUTH HELPER FUNCTIONS
-- ============================================================

-- Returns the tenant_id for the currently authenticated user.
-- Returns NULL if no session or user without a profile.
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

-- Returns the role for the currently authenticated user.
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

-- Returns TRUE if the current user has at least the given role (hierarchy: owner > manager > trainer > receptionist).
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

-- 3. TABLES
-- ============================================================

-- 3.1 TENANTS
CREATE TABLE IF NOT EXISTS public.tenants (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                text NOT NULL,
  slug                text NOT NULL UNIQUE,
  domain              text UNIQUE,
  logo_url            text,
  address             jsonb,
  phone               text,
  email               text,
  settings            jsonb DEFAULT '{}'::jsonb,
  subscription_status subscription_status NOT NULL DEFAULT 'trialing',
  subscription_plan   text NOT NULL DEFAULT 'starter',
  stripe_customer_id  text UNIQUE,
  stripe_subscription_id text UNIQUE,
  is_active           boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tenants_slug ON public.tenants (slug);
CREATE INDEX IF NOT EXISTS idx_tenants_domain ON public.tenants (domain);

-- 3.2 PROFILES (staff)
CREATE TABLE IF NOT EXISTS public.profiles (
  id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  role        user_role NOT NULL DEFAULT 'receptionist',
  full_name   text NOT NULL,
  email       text NOT NULL,
  phone       text,
  avatar_url  text,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_tenant_email ON public.profiles (tenant_id, email);
CREATE INDEX IF NOT EXISTS idx_profiles_tenant_id ON public.profiles (tenant_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles (role);

-- 3.3 MEMBERSHIP TYPES
CREATE TABLE IF NOT EXISTS public.membership_types (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name          text NOT NULL,
  duration_days integer NOT NULL CHECK (duration_days > 0),
  price         decimal(10,2) NOT NULL CHECK (price >= 0),
  description   text,
  features      jsonb DEFAULT '[]'::jsonb,
  is_active     boolean NOT NULL DEFAULT true,
  sort_order    integer NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_membership_types_tenant ON public.membership_types (tenant_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_membership_types_tenant_name ON public.membership_types (tenant_id, name);

-- 3.4 MEMBERS
CREATE TABLE IF NOT EXISTS public.members (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id           uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  membership_type_id uuid REFERENCES public.membership_types(id) ON DELETE SET NULL,
  member_code       text NOT NULL,
  full_name         text NOT NULL,
  email             text,
  phone             text,
  date_of_birth     date,
  gender            text,
  address           jsonb,
  emergency_contact jsonb,
  photo_url         text,
  join_date         date NOT NULL DEFAULT CURRENT_DATE,
  membership_start  date,
  membership_end    date,
  status            member_status NOT NULL DEFAULT 'active',
  notes             text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_members_tenant_code ON public.members (tenant_id, member_code);
CREATE UNIQUE INDEX IF NOT EXISTS idx_members_tenant_email ON public.members (tenant_id, email) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_members_tenant_id ON public.members (tenant_id);
CREATE INDEX IF NOT EXISTS idx_members_status ON public.members (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_members_membership_end ON public.members (tenant_id, membership_end);
CREATE INDEX IF NOT EXISTS idx_members_user_id ON public.members (user_id);

-- 3.5 ATTENDANCE
CREATE TABLE IF NOT EXISTS public.attendance (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  member_id       uuid NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  checked_in_by   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  check_in_method check_in_method NOT NULL DEFAULT 'manual',
  check_in_time   timestamptz NOT NULL DEFAULT now(),
  check_out_time  timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_check_out_after_in CHECK (check_out_time IS NULL OR check_out_time > check_in_time)
);

CREATE INDEX IF NOT EXISTS idx_attendance_tenant_date ON public.attendance (tenant_id, check_in_time DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_member_date ON public.attendance (member_id, check_in_time DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON public.attendance (check_in_time::date);

-- 3.6 PAYMENTS
CREATE TABLE IF NOT EXISTS public.payments (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  member_id         uuid NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  membership_type_id uuid REFERENCES public.membership_types(id) ON DELETE SET NULL,
  amount            decimal(10,2) NOT NULL CHECK (amount > 0),
  payment_date      date NOT NULL DEFAULT CURRENT_DATE,
  due_date          date,
  payment_method    payment_method NOT NULL DEFAULT 'cash',
  status            payment_status NOT NULL DEFAULT 'pending',
  reference_number  text,
  notes             text,
  receipt_url       text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_tenant_date ON public.payments (tenant_id, payment_date DESC);
CREATE INDEX IF NOT EXISTS idx_payments_member ON public.payments (member_id, payment_date DESC);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_payments_membership_type ON public.payments (membership_type_id);

-- 3.7 EXERCISES (global + tenant-custom)
CREATE TABLE IF NOT EXISTS public.exercises (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name          text NOT NULL,
  description   text,
  muscle_group  muscle_group,
  equipment     text,
  video_url     text,
  image_url     text,
  is_custom     boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_exercises_tenant_name ON public.exercises (tenant_id, name);
CREATE INDEX IF NOT EXISTS idx_exercises_muscle_group ON public.exercises (tenant_id, muscle_group);

-- 3.8 WORKOUTS
CREATE TABLE IF NOT EXISTS public.workouts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  member_id       uuid NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  trainer_id      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  name            text,
  scheduled_date  date NOT NULL,
  status          workout_status NOT NULL DEFAULT 'scheduled',
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_workouts_tenant_member ON public.workouts (tenant_id, member_id, scheduled_date DESC);
CREATE INDEX IF NOT EXISTS idx_workouts_trainer ON public.workouts (trainer_id, scheduled_date DESC);
CREATE INDEX IF NOT EXISTS idx_workouts_date ON public.workouts (tenant_id, scheduled_date);

-- 3.9 WORKOUT EXERCISES
CREATE TABLE IF NOT EXISTS public.workout_exercises (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id      uuid NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
  exercise_id     uuid NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
  sets            integer CHECK (sets > 0),
  reps            integer CHECK (reps > 0),
  weight          decimal(6,2) CHECK (weight >= 0),
  duration_seconds integer CHECK (duration_seconds > 0),
  rest_seconds    integer CHECK (rest_seconds >= 0),
  notes           text,
  sort_order      integer NOT NULL DEFAULT 0,
  completed_sets  jsonb DEFAULT '[]'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_workout_exercises_workout ON public.workout_exercises (workout_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_workout_exercises_exercise ON public.workout_exercises (exercise_id);

-- 3.10 DIET PLANS
CREATE TABLE IF NOT EXISTS public.diet_plans (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  member_id        uuid NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  trainer_id       uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  name             text NOT NULL,
  start_date       date,
  end_date         date,
  daily_calories   integer CHECK (daily_calories > 0),
  daily_protein_g  decimal(6,1) CHECK (daily_protein_g >= 0),
  daily_carbs_g    decimal(6,1) CHECK (daily_carbs_g >= 0),
  daily_fat_g      decimal(6,1) CHECK (daily_fat_g >= 0),
  notes            text,
  is_active        boolean NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_diet_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date > start_date)
);

CREATE INDEX IF NOT EXISTS idx_diet_plans_tenant_member ON public.diet_plans (tenant_id, member_id);
CREATE INDEX IF NOT EXISTS idx_diet_plans_active ON public.diet_plans (tenant_id, is_active) WHERE is_active = true;

-- 3.11 DIET PLAN MEALS
CREATE TABLE IF NOT EXISTS public.diet_plan_meals (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  diet_plan_id uuid NOT NULL REFERENCES public.diet_plans(id) ON DELETE CASCADE,
  meal_name   text NOT NULL,
  day_of_week integer CHECK (day_of_week BETWEEN 0 AND 6),
  meal_time   time,
  foods       jsonb NOT NULL DEFAULT '[]'::jsonb,
  sort_order  integer NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_diet_plan_meals_plan ON public.diet_plan_meals (diet_plan_id, sort_order);

-- 3.12 PROGRESS PHOTOS
CREATE TABLE IF NOT EXISTS public.progress_photos (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  member_id   uuid NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  uploaded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  photo_url   text NOT NULL,
  photo_type  photo_type NOT NULL DEFAULT 'front',
  photo_date  date NOT NULL DEFAULT CURRENT_DATE,
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_progress_photos_member_date ON public.progress_photos (member_id, photo_date DESC);
CREATE INDEX IF NOT EXISTS idx_progress_photos_tenant ON public.progress_photos (tenant_id);

-- 3.13 MEMBER QR CODES
CREATE TABLE IF NOT EXISTS public.member_qr_codes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  member_id       uuid NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  qr_hash         text NOT NULL UNIQUE,
  is_active       boolean NOT NULL DEFAULT true,
  expires_at      timestamptz,
  regenerated_at  timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_qr_codes_member ON public.member_qr_codes (member_id);
CREATE INDEX IF NOT EXISTS idx_qr_codes_hash ON public.member_qr_codes (qr_hash);

-- 3.14 AUDIT LOGS (append-only)
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  actor_id    uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  action      text NOT NULL,
  entity_type text NOT NULL,
  entity_id   uuid,
  changes     jsonb,
  ip_address  inet,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_action ON public.audit_logs (tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON public.audit_logs (entity_type, entity_id);

-- 3.15 SUBSCRIPTION EVENTS (Stripe sync log)
CREATE TABLE IF NOT EXISTS public.subscription_events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid REFERENCES public.tenants(id) ON DELETE SET NULL,
  event_type   text NOT NULL,
  stripe_data  jsonb NOT NULL,
  processed    boolean NOT NULL DEFAULT false,
  error        text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subscription_events_tenant ON public.subscription_events (tenant_id);
CREATE INDEX IF NOT EXISTS idx_subscription_events_processed ON public.subscription_events (processed) WHERE processed = false;

-- ============================================================
-- 4. TRIGGER FUNCTIONS
-- ============================================================

-- 4.1 Auto-assign tenant_id on INSERT for all tenant-scoped tables
CREATE OR REPLACE FUNCTION public.set_tenant_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.tenant_id IS NULL THEN
    NEW.tenant_id := auth.current_tenant_id();
  END IF;
  IF NEW.tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required and could not be determined from session';
  END IF;
  RETURN NEW;
END;
$$;

-- 4.2 Auto-generate member_code on INSERT for members
CREATE OR REPLACE FUNCTION public.generate_member_code()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  gym_slug text;
  seq_num  integer;
BEGIN
  SELECT slug INTO gym_slug FROM public.tenants WHERE id = NEW.tenant_id;
  seq_num := nextval('public.member_code_seq');
  NEW.member_code := UPPER(SUBSTRING(gym_slug, 1, 3)) || LPAD(seq_num::text, 6, '0');
  RETURN NEW;
END;
$$;

-- Sequence for member codes
CREATE SEQUENCE IF NOT EXISTS public.member_code_seq START 1;

-- 4.3 Auto-generate QR hash on INSERT for member_qr_codes
CREATE OR REPLACE FUNCTION public.generate_qr_hash()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  qr_secret text;
BEGIN
  qr_secret := current_setting('app.settings.qr_secret', true);
  IF qr_secret IS NULL THEN
    RAISE EXCEPTION 'app.settings.qr_secret must be configured';
  END IF;
  NEW.qr_hash := ENCODE(
    HMAC(
      CAST(NEW.tenant_id AS text) || CAST(NEW.member_id AS text) || NEW.created_at::text,
      qr_secret,
      'sha256'
    ),
    'hex'
  );
  NEW.regenerated_at := now();
  RETURN NEW;
END;
$$;

-- 4.4 Update updated_at timestamp
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- 4.5 Update membership_end on payment insert
CREATE OR REPLACE FUNCTION public.update_membership_on_payment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  duration integer;
  new_end date;
BEGIN
  IF NEW.status = 'completed' AND NEW.membership_type_id IS NOT NULL THEN
    SELECT duration_days INTO duration
    FROM public.membership_types
    WHERE id = NEW.membership_type_id;

    IF FOUND THEN
      SELECT COALESCE(membership_end, CURRENT_DATE) INTO new_end
      FROM public.members
      WHERE id = NEW.member_id;

      UPDATE public.members
      SET
        membership_end = new_end + duration,
        membership_start = COALESCE(membership_start, CURRENT_DATE),
        status = 'active',
        updated_at = now()
      WHERE id = NEW.member_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- 4.6 Log audit entries
CREATE OR REPLACE FUNCTION public.log_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  action_name text;
  changes_json jsonb;
BEGIN
  IF TG_OP = 'INSERT' THEN
    action_name := TG_TABLE_NAME || '.created';
    changes_json := row_to_json(NEW)::jsonb;
  ELSIF TG_OP = 'UPDATE' THEN
    action_name := TG_TABLE_NAME || '.updated';
    changes_json := jsonb_build_object(
      'old', row_to_json(OLD)::jsonb,
      'new', row_to_json(NEW)::jsonb
    );
  ELSIF TG_OP = 'DELETE' THEN
    action_name := TG_TABLE_NAME || '.deleted';
    changes_json := row_to_json(OLD)::jsonb;
  END IF;

  INSERT INTO public.audit_logs (tenant_id, actor_id, action, entity_type, entity_id, changes, ip_address)
  VALUES (
    COALESCE(NEW.tenant_id, OLD.tenant_id),
    auth.uid(),
    action_name,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    changes_json,
    inet_client_addr()
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- ============================================================
-- 5. TRIGGERS
-- ============================================================

-- 5.1 Tenant_id assignment triggers
CREATE TRIGGER trg_set_tenant_id_profiles
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id();

CREATE TRIGGER trg_set_tenant_id_membership_types
  BEFORE INSERT ON public.membership_types
  FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id();

CREATE TRIGGER trg_set_tenant_id_members
  BEFORE INSERT ON public.members
  FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id();

CREATE TRIGGER trg_set_tenant_id_attendance
  BEFORE INSERT ON public.attendance
  FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id();

CREATE TRIGGER trg_set_tenant_id_payments
  BEFORE INSERT ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id();

CREATE TRIGGER trg_set_tenant_id_exercises
  BEFORE INSERT ON public.exercises
  FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id();

CREATE TRIGGER trg_set_tenant_id_workouts
  BEFORE INSERT ON public.workouts
  FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id();

CREATE TRIGGER trg_set_tenant_id_diet_plans
  BEFORE INSERT ON public.diet_plans
  FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id();

CREATE TRIGGER trg_set_tenant_id_progress_photos
  BEFORE INSERT ON public.progress_photos
  FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id();

CREATE TRIGGER trg_set_tenant_id_qr_codes
  BEFORE INSERT ON public.member_qr_codes
  FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id();

-- 5.2 Member code generation
CREATE TRIGGER trg_generate_member_code
  BEFORE INSERT ON public.members
  FOR EACH ROW
  WHEN (NEW.member_code IS NULL)
  EXECUTE FUNCTION public.generate_member_code();

-- 5.3 QR hash generation
CREATE TRIGGER trg_generate_qr_hash
  BEFORE INSERT ON public.member_qr_codes
  FOR EACH ROW
  WHEN (NEW.qr_hash IS NULL)
  EXECUTE FUNCTION public.generate_qr_hash();

-- 5.4 Updated_at triggers
CREATE TRIGGER trg_set_updated_at_tenants
  BEFORE UPDATE ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_set_updated_at_profiles
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_set_updated_at_membership_types
  BEFORE UPDATE ON public.membership_types
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_set_updated_at_members
  BEFORE UPDATE ON public.members
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_set_updated_at_payments
  BEFORE UPDATE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_set_updated_at_workouts
  BEFORE UPDATE ON public.workouts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_set_updated_at_diet_plans
  BEFORE UPDATE ON public.diet_plans
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 5.5 Membership auto-renewal on completed payment
CREATE TRIGGER trg_update_membership_on_payment
  AFTER INSERT ON public.payments
  FOR EACH ROW
  WHEN (NEW.status = 'completed')
  EXECUTE FUNCTION public.update_membership_on_payment();

-- 5.6 Audit log triggers (critical tables only to avoid noise)
CREATE TRIGGER trg_audit_members
  AFTER INSERT OR UPDATE OR DELETE ON public.members
  FOR EACH ROW EXECUTE FUNCTION public.log_audit();

CREATE TRIGGER trg_audit_payments
  AFTER INSERT OR UPDATE OR DELETE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.log_audit();

CREATE TRIGGER trg_audit_profiles
  AFTER INSERT OR UPDATE OR DELETE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit();

-- ============================================================
-- 6. ROW LEVEL SECURITY
-- ============================================================

-- 6.1 Enable RLS on all tenant-scoped tables
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_plan_meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 6.2 Universal helper: only allow access to rows belonging to the user's tenant
-- These policies apply to every tenant-scoped table.

-- TENANTS
CREATE POLICY tenant_isolation_select ON public.tenants
  FOR SELECT
  USING (id = auth.current_tenant_id());

CREATE POLICY tenant_isolation_update ON public.tenants
  FOR UPDATE
  USING (id = auth.current_tenant_id() AND auth.user_role() = 'owner')
  WITH CHECK (id = auth.current_tenant_id() AND auth.user_role() = 'owner');

-- PROFILES
CREATE POLICY profiles_select ON public.profiles
  FOR SELECT
  USING (
    id = auth.uid()  -- yourself
    OR tenant_id = auth.current_tenant_id()  -- same tenant staff
  );

CREATE POLICY profiles_insert ON public.profiles
  FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('manager')
  );

CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE
  USING (
    tenant_id = auth.current_tenant_id()
    AND (
      id = auth.uid()  -- update yourself
      OR auth.has_role('manager')  -- manager can update others
    )
  )
  WITH CHECK (
    CASE
      WHEN id = auth.uid() THEN tenant_id = auth.current_tenant_id()
      ELSE auth.has_role('manager')
    END
  );

CREATE POLICY profiles_delete ON public.profiles
  FOR DELETE
  USING (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('owner')
    AND id <> auth.uid()  -- can't delete yourself
  );

-- GENERIC TENANT-ISOLATED POLICY (applied to all remaining tables)
-- SELECT: same tenant
-- INSERT: same tenant + minimum role
-- UPDATE: same tenant + minimum role
-- DELETE: same tenant + minimum role

-- MEMBERS
CREATE POLICY members_select ON public.members
  FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY members_insert ON public.members
  FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY members_update ON public.members
  FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('trainer'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY members_delete ON public.members
  FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- MEMBERSHIP TYPES
CREATE POLICY membership_types_select ON public.membership_types
  FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY membership_types_insert ON public.membership_types
  FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('manager')
  );

CREATE POLICY membership_types_update ON public.membership_types
  FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY membership_types_delete ON public.membership_types
  FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- ATTENDANCE
CREATE POLICY attendance_select ON public.attendance
  FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY attendance_insert ON public.attendance
  FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('receptionist')
  );

CREATE POLICY attendance_update ON public.attendance
  FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('trainer'))
  WITH CHECK (tenant_id = auth.current_tenant_id() AND check_out_time IS NOT NULL);

CREATE POLICY attendance_delete ON public.attendance
  FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- PAYMENTS
CREATE POLICY payments_select ON public.payments
  FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY payments_insert ON public.payments
  FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('receptionist')
  );

CREATE POLICY payments_update ON public.payments
  FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY payments_delete ON public.payments
  FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- EXERCISES
CREATE POLICY exercises_select ON public.exercises
  FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY exercises_insert ON public.exercises
  FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY exercises_update ON public.exercises
  FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('trainer'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY exercises_delete ON public.exercises
  FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- WORKOUTS
CREATE POLICY workouts_select ON public.workouts
  FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY workouts_insert ON public.workouts
  FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY workouts_update ON public.workouts
  FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('trainer'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY workouts_delete ON public.workouts
  FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- WORKOUT EXERCISES (access via workout)
CREATE POLICY workout_exercises_select ON public.workout_exercises
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.workouts
      WHERE id = workout_id AND tenant_id = auth.current_tenant_id()
    )
  );

CREATE POLICY workout_exercises_insert ON public.workout_exercises
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.workouts
      WHERE id = workout_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('trainer')
  );

CREATE POLICY workout_exercises_update ON public.workout_exercises
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.workouts
      WHERE id = workout_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('trainer')
  );

CREATE POLICY workout_exercises_delete ON public.workout_exercises
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.workouts
      WHERE id = workout_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('manager')
  );

-- DIET PLANS
CREATE POLICY diet_plans_select ON public.diet_plans
  FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY diet_plans_insert ON public.diet_plans
  FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY diet_plans_update ON public.diet_plans
  FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('trainer'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY diet_plans_delete ON public.diet_plans
  FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- DIET PLAN MEALS
CREATE POLICY diet_plan_meals_select ON public.diet_plan_meals
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.diet_plans
      WHERE id = diet_plan_id AND tenant_id = auth.current_tenant_id()
    )
  );

CREATE POLICY diet_plan_meals_insert ON public.diet_plan_meals
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.diet_plans
      WHERE id = diet_plan_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('trainer')
  );

CREATE POLICY diet_plan_meals_update ON public.diet_plan_meals
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.diet_plans
      WHERE id = diet_plan_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('trainer')
  );

CREATE POLICY diet_plan_meals_delete ON public.diet_plan_meals
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.diet_plans
      WHERE id = diet_plan_id AND tenant_id = auth.current_tenant_id()
    )
    AND auth.has_role('manager')
  );

-- PROGRESS PHOTOS
CREATE POLICY progress_photos_select ON public.progress_photos
  FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY progress_photos_insert ON public.progress_photos
  FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY progress_photos_update ON public.progress_photos
  FOR UPDATE
  USING (
    tenant_id = auth.current_tenant_id()
    AND (uploaded_by = auth.uid() OR auth.has_role('manager'))
  )
  WITH CHECK (tenant_id = auth.current_tenant_id());

CREATE POLICY progress_photos_delete ON public.progress_photos
  FOR DELETE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('manager'));

-- MEMBER QR CODES
CREATE POLICY qr_codes_select ON public.member_qr_codes
  FOR SELECT
  USING (tenant_id = auth.current_tenant_id());

CREATE POLICY qr_codes_insert ON public.member_qr_codes
  FOR INSERT
  WITH CHECK (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('trainer')
  );

CREATE POLICY qr_codes_update ON public.member_qr_codes
  FOR UPDATE
  USING (tenant_id = auth.current_tenant_id() AND auth.has_role('trainer'))
  WITH CHECK (tenant_id = auth.current_tenant_id());

-- AUDIT LOGS (append-only read)
CREATE POLICY audit_logs_select ON public.audit_logs
  FOR SELECT
  USING (
    tenant_id = auth.current_tenant_id()
    AND auth.has_role('manager')
  );

-- ============================================================
-- 7. STORAGE RLS
-- ============================================================

-- Create buckets (run in Supabase dashboard or via SQL)
-- NOTE: This requires the storage extension; run separately if needed.

DO $$ BEGIN
  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  VALUES
    ('progress-photos', 'progress-photos', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('tenant-assets', 'tenant-assets', false, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'])
  ON CONFLICT (id) DO NOTHING;
END $$;

-- Storage RLS policies
DO $$ BEGIN
  CREATE POLICY "progress_photos_select" ON storage.objects
    FOR SELECT
    USING (
      bucket_id = 'progress-photos'
      AND auth.role() = 'authenticated'
      AND storage.foldername(name)[1] = auth.current_tenant_id()::text
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "progress_photos_insert" ON storage.objects
    FOR INSERT
    WITH CHECK (
      bucket_id = 'progress-photos'
      AND auth.role() = 'authenticated'
      AND storage.foldername(name)[1] = auth.current_tenant_id()::text
      AND auth.has_role('trainer')
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "progress_photos_update" ON storage.objects
    FOR UPDATE
    USING (
      bucket_id = 'progress-photos'
      AND auth.role() = 'authenticated'
      AND storage.foldername(name)[1] = auth.current_tenant_id()::text
      AND auth.has_role('trainer')
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "progress_photos_delete" ON storage.objects
    FOR DELETE
    USING (
      bucket_id = 'progress-photos'
      AND auth.role() = 'authenticated'
      AND storage.foldername(name)[1] = auth.current_tenant_id()::text
      AND auth.has_role('manager')
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "tenant_assets_select" ON storage.objects
    FOR SELECT
    USING (
      bucket_id = 'tenant-assets'
      AND auth.role() = 'authenticated'
      AND storage.foldername(name)[1] = auth.current_tenant_id()::text
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "tenant_assets_insert" ON storage.objects
    FOR INSERT
    WITH CHECK (
      bucket_id = 'tenant-assets'
      AND auth.role() = 'authenticated'
      AND storage.foldername(name)[1] = auth.current_tenant_id()::text
      AND auth.has_role('manager')
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- 8. HANDLE NEW USER SIGNUP (auto-create profile + tenant)
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_tenant_id uuid;
  user_email    text;
BEGIN
  user_email := COALESCE(NEW.email, NEW.raw_user_meta_data->>'email');

  -- Check if signing up with an invite token (joining existing tenant)
  IF NEW.raw_user_meta_data ? 'invite_token' AND NEW.raw_user_meta_data ? 'tenant_id' THEN
    -- Profile already created by owner, just link it
    UPDATE public.profiles
    SET is_active = true
    WHERE email = user_email
      AND tenant_id = (NEW.raw_user_meta_data->>'tenant_id')::uuid
      AND id IS DISTINCT FROM NEW.id;
    RETURN NEW;
  END IF;

  -- First user = new tenant (owner)
  INSERT INTO public.tenants (name, slug, email)
  VALUES (
    COALESCE(NEW.raw_user_meta_data->>'gym_name', user_email || '''s Gym'),
    LOWER(REGEXP_REPLACE(
      REGEXP_REPLACE(
        COALESCE(NEW.raw_user_meta_data->>'gym_name', user_email),
        '[^a-zA-Z0-9]+', '-', 'g'
      ),
      '^-|-$', '', 'g'
    )) || '-' || SUBSTR(MD5(NEW.id::text || clock_timestamp()::text)::text, 1, 6),
    user_email
  )
  RETURNING id INTO new_tenant_id;

  INSERT INTO public.profiles (id, tenant_id, role, full_name, email)
  VALUES (NEW.id, new_tenant_id, 'owner', COALESCE(NEW.raw_user_meta_data->>'full_name', user_email), user_email);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 9. REALTIME (enable for live features)
-- ============================================================

-- Enable realtime for tables that need live updates
ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance;
ALTER PUBLICATION supabase_realtime ADD TABLE public.workouts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.workout_exercises;

-- ============================================================
-- DONE
-- ============================================================
