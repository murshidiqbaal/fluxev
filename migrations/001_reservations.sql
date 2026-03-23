-- 1. Update connector_status enum to include 'reserved'
ALTER TYPE public.connector_status ADD VALUE IF NOT EXISTS 'reserved';

-- 2. Create reservations table with explicit foreign keys
CREATE TABLE IF NOT EXISTS public.reservations (
    reservation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    connector_id UUID NOT NULL REFERENCES public.connectors(id) ON DELETE CASCADE,
    reserved_start TIMESTAMPTZ NOT NULL,
    reserved_end TIMESTAMPTZ NOT NULL,
    reservation_fee NUMERIC(6,2) NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'expired', 'completed')),
    created_at TIMESTAMPTZ DEFAULT now(),
    
    CONSTRAINT reservation_time_check CHECK (reserved_start < reserved_end)
);

-- Ensure Foreign Keys are indexed for joins
CREATE INDEX IF NOT EXISTS idx_res_user_id ON public.reservations(user_id);
CREATE INDEX IF NOT EXISTS idx_res_station_id ON public.reservations(station_id);
CREATE INDEX IF NOT EXISTS idx_res_connector_id ON public.reservations(connector_id);

-- 3. Create Index for conflict checking
CREATE INDEX IF NOT EXISTS idx_reservation_connector_time 
ON public.reservations (connector_id, reserved_start, reserved_end) 
WHERE (status = 'active');

-- 4. Enable RLS
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies
DROP POLICY IF EXISTS "Users can view their own reservations" ON public.reservations;
CREATE POLICY "Users can view their own reservations" 
ON public.reservations FOR SELECT 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own reservations" ON public.reservations;
CREATE POLICY "Users can create their own reservations" 
ON public.reservations FOR INSERT 
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all reservations" ON public.reservations;
CREATE POLICY "Admins can view all reservations" 
ON public.reservations FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

DROP POLICY IF EXISTS "Admins can update all reservations" ON public.reservations;
CREATE POLICY "Admins can update all reservations" 
ON public.reservations FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- 6. Atomic Function for Reservation & Payment
CREATE OR REPLACE FUNCTION public.create_reservation_with_payment(
    p_connector_id UUID,
    p_station_id UUID,
    p_start TIMESTAMPTZ,
    p_end TIMESTAMPTZ,
    p_fee NUMERIC
) RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_wallet_id UUID;
    v_balance NUMERIC;
    v_conflict_exists BOOLEAN;
    v_reservation_id UUID;
BEGIN
    -- 1. Get current user
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    -- 2. Check for overlapping reservations
    SELECT EXISTS (
        SELECT 1 FROM public.reservations
        WHERE connector_id = p_connector_id
        AND status = 'active'
        AND reserved_start < p_end
        AND reserved_end > p_start
    ) INTO v_conflict_exists;

    IF v_conflict_exists THEN
        RETURN jsonb_build_object('success', false, 'message', 'Connector already reserved for this time slot');
    END IF;

    -- 4. Check Wallet Balance
    -- Note: Using wallet_id as primary key if 'id' causing 42703 error
    SELECT wallet_id, balance INTO v_wallet_id, v_balance 
    FROM public.wallets 
    WHERE user_id = v_user_id;

    IF v_balance < p_fee THEN
        RETURN jsonb_build_object('success', false, 'message', 'Insufficient wallet balance');
    END IF;

    -- 5. Deduct Balance
    UPDATE public.wallets 
    SET balance = balance - p_fee, updated_at = now()
    WHERE wallet_id = v_wallet_id;

    -- 6. Record Transaction
    INSERT INTO public.transactions (wallet_id, amount, type, created_at)
    VALUES (v_wallet_id, p_fee, 'debit'::transaction_type, now());

    -- 7. Insert Reservation
    INSERT INTO public.reservations (
        user_id, station_id, connector_id, reserved_start, reserved_end, reservation_fee, status
    ) VALUES (
        v_user_id, p_station_id, p_connector_id, p_start, p_end, p_fee, 'active'
    ) RETURNING reservation_id INTO v_reservation_id;

    -- 8. Update connector status if starts now
    IF now() >= p_start AND now() < p_end THEN
        UPDATE public.connectors SET status = 'reserved' WHERE id = p_connector_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true, 
        'reservation_id', v_reservation_id,
        'message', 'Reservation successful'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.reservations;
