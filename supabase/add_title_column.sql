-- Add title column to notes table
-- Run this in the Supabase SQL Editor

ALTER TABLE public.notes 
ADD COLUMN IF NOT EXISTS title TEXT;

-- Add index for title search (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_notes_title ON public.notes(title);

-- Note: title is nullable, so existing notes will have NULL title
-- The app will fall back to displaying the first line of content
