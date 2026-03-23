-- 1. Identify and drop the broken foreign key on transactions
DO $$ 
DECLARE 
    fk_name TEXT;
BEGIN 
    SELECT conname INTO fk_name
    FROM pg_constraint 
    WHERE conrelid = 'public.transactions'::regclass 
    AND confrelid = 'public.wallets'::regclass;

    IF fk_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.transactions DROP CONSTRAINT ' || fk_name;
    END IF;
END $$;

-- 2. Ensure wallets table primary key is wallet_id (if not already)
-- Note: If wallet_id is already the PK, this will just confirm the structure.
DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'wallets' AND column_name = 'wallet_id'
    ) THEN
        -- If it's still named 'id', rename it to 'wallet_id'
        ALTER TABLE public.wallets RENAME COLUMN id TO wallet_id;
    END IF;
END $$;

-- 3. Add the correct foreign key constraint back to transactions
ALTER TABLE public.transactions 
ADD CONSTRAINT transactions_wallet_id_fkey 
FOREIGN KEY (wallet_id) REFERENCES public.wallets(wallet_id) 
ON DELETE CASCADE;

-- 4. Fix any other referencing tables if they exist
-- Charging Sessions (if it references wallets, though usually it references sessions/transactions)
-- No other tables in the provided schema reference wallets directly.

-- 5. Verification
-- This query should now work without the "column id does not exist" error
SELECT wallet_id, balance FROM public.wallets LIMIT 1;
