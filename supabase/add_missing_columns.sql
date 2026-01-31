-- ===========================================
-- Add missing columns to notes table
-- Run this BEFORE demo_data.sql
-- ===========================================

-- Add title column (optional custom title for notes)
ALTER TABLE public.notes 
ADD COLUMN IF NOT EXISTS title TEXT;

-- Add last_edited column (when content was last changed)
ALTER TABLE public.notes 
ADD COLUMN IF NOT EXISTS last_edited TIMESTAMPTZ DEFAULT NOW();

-- Create index for last_edited for better performance
CREATE INDEX IF NOT EXISTS idx_notes_last_edited ON public.notes(last_edited DESC);

-- ===========================================
-- After running this, delete all existing demo notes:
-- DELETE FROM public.notes WHERE user_id = '743286b1-6f81-4418-afef-56d0fd520ad5';
-- Then run demo_data.sql again
-- ===========================================
