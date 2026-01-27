-- ===========================================
-- NoteFlow Schema Updates
-- Run this in the Supabase SQL Editor
-- ===========================================

-- 1. Add last_edited column to notes table
ALTER TABLE public.notes 
ADD COLUMN IF NOT EXISTS last_edited TIMESTAMPTZ DEFAULT NOW();

-- Set last_edited = created_at for existing notes
UPDATE public.notes 
SET last_edited = created_at 
WHERE last_edited IS NULL;

-- 2. Create analytics_tag_corrections table
CREATE TABLE IF NOT EXISTS public.analytics_tag_corrections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  note_id UUID,
  note_content TEXT, -- First 100 chars for ML training context
  original_tags TEXT[], -- Auto-generated tags
  final_tags TEXT[], -- User-corrected tags
  added_tags TEXT[], -- Tags added by user
  removed_tags TEXT[], -- Tags removed by user
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for analytics table
CREATE INDEX IF NOT EXISTS idx_tag_corrections_user ON public.analytics_tag_corrections(user_id);
CREATE INDEX IF NOT EXISTS idx_tag_corrections_removed ON public.analytics_tag_corrections USING GIN(removed_tags);
CREATE INDEX IF NOT EXISTS idx_tag_corrections_created ON public.analytics_tag_corrections(created_at DESC);

-- Enable Row Level Security on analytics table
ALTER TABLE public.analytics_tag_corrections ENABLE ROW LEVEL SECURITY;

-- RLS Policies for analytics_tag_corrections

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own analytics" ON public.analytics_tag_corrections;
DROP POLICY IF EXISTS "Users can insert own analytics" ON public.analytics_tag_corrections;
DROP POLICY IF EXISTS "Users can update own analytics" ON public.analytics_tag_corrections;
DROP POLICY IF EXISTS "Users can delete own analytics" ON public.analytics_tag_corrections;

-- Policy: Users can view their own analytics
CREATE POLICY "Users can view own analytics" 
    ON public.analytics_tag_corrections 
    FOR SELECT 
    USING (auth.uid() = user_id);

-- Policy: Users can insert their own analytics
CREATE POLICY "Users can insert own analytics" 
    ON public.analytics_tag_corrections 
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own analytics (for synced flag)
CREATE POLICY "Users can update own analytics" 
    ON public.analytics_tag_corrections 
    FOR UPDATE 
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own analytics
CREATE POLICY "Users can delete own analytics" 
    ON public.analytics_tag_corrections 
    FOR DELETE 
    USING (auth.uid() = user_id);

-- ===========================================
-- Done! Your schema is now up to date.
-- ===========================================
