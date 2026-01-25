-- Migration: Add last_edited column to notes table
-- Run this in Supabase SQL Editor

-- Step 1: Add the new column with a default value
ALTER TABLE notes ADD COLUMN last_edited TIMESTAMPTZ DEFAULT NOW();

-- Step 2: Backfill existing notes (use created_at as initial value)
UPDATE notes SET last_edited = created_at WHERE last_edited IS NULL;

-- Step 3: Make it non-nullable after backfill
ALTER TABLE notes ALTER COLUMN last_edited SET NOT NULL;

-- Verify the column was added successfully
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'notes' 
AND column_name = 'last_edited';
