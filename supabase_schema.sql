-- 1. Create enum types for structured statuses
CREATE TYPE user_role AS ENUM ('guest', 'user', 'admin');
CREATE TYPE station_status AS ENUM ('active', 'inactive');
CREATE TYPE connector_status AS ENUM ('available', 'busy', 'offline');
CREATE TYPE session_status AS ENUM ('active', 'completed', 'failed');
CREATE TYPE transaction_type AS ENUM ('credit', 'debit');

-- 2. Users Table (extends auth.users)
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  role user_role DEFAULT 'user'::user_role,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Stations Table
CREATE TABLE public.stations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  price_per_kwh NUMERIC NOT NULL DEFAULT 0.0,
  status station_status DEFAULT 'active'::station_status,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES public.users(id)
);

-- 4. Connectors Table
CREATE TABLE public.connectors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
  connector_type TEXT NOT NULL,
  max_power_kw NUMERIC NOT NULL,
  status connector_status DEFAULT 'available'::connector_status,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Charging Sessions Table
CREATE TABLE public.charging_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  connector_id UUID NOT NULL REFERENCES public.connectors(id) ON DELETE CASCADE,
  start_time TIMESTAMPTZ DEFAULT now(),
  end_time TIMESTAMPTZ,
  energy_consumed_kwh NUMERIC DEFAULT 0.0,
  total_cost NUMERIC DEFAULT 0.0,
  status session_status DEFAULT 'active'::session_status
);

-- 6. Wallets Table
CREATE TABLE public.wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  balance NUMERIC DEFAULT 0.0,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 7. Transactions Table
CREATE TABLE public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  session_id UUID REFERENCES public.charging_sessions(id) ON DELETE SET NULL,
  amount NUMERIC NOT NULL,
  type transaction_type NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. Reviews Table
CREATE TABLE public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Trigger to automatically create a wallet when a new user is created
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, full_name, email, role)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.email, 'user'::user_role);

  INSERT INTO public.wallets (user_id, balance)
  VALUES (new.id, 100.00); -- Giving demo balance
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Enable Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connectors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.charging_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Basic Policies Sample
CREATE POLICY "Users can view all stations" ON public.stations FOR SELECT USING (true);
CREATE POLICY "Users can view all connectors" ON public.connectors FOR SELECT USING (true);

-- Enable Realtime
-- This requires turning on CDC repl in Supabase for these tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.connectors;
ALTER PUBLICATION supabase_realtime ADD TABLE public.stations;

