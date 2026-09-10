-- Drop incorrect tables from migration 001 (if they exist)
DROP TABLE IF EXISTS public.usage_daily CASCADE;
DROP TABLE IF EXISTS public.subscriptions CASCADE;

-- ─── subscriptions ───────────────────────────────────────────────────────────
CREATE TABLE public.subscriptions (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier       TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro')),
  expires_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create a free-tier row for every new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.subscriptions (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ─── usage_daily ─────────────────────────────────────────────────────────────
CREATE TABLE public.usage_daily (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date    DATE NOT NULL DEFAULT CURRENT_DATE,
  count   INT  NOT NULL DEFAULT 0 CHECK (count >= 0),
  PRIMARY KEY (user_id, date)
);

-- ─── RLS ─────────────────────────────────────────────────────────────────────
-- Edge Functions use service_role key (bypasses RLS).
-- Flutter client must never query these tables directly.
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_daily   ENABLE ROW LEVEL SECURITY;
-- No policies — service_role only.
