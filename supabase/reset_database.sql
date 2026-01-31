    -- ===========================================
    -- NoteFlow Database Reset Script
    -- DANGER: This will DELETE ALL DATA AND USERS!
    -- Run this in the Supabase SQL Editor
    -- ===========================================

    -- 1. DELETE ALL AUTHENTICATION USERS
    -- This will cascade and delete all related notes/analytics due to ON DELETE CASCADE
    DELETE FROM auth.users;

    -- 2. DROP ALL EXISTING POLICIES
    DROP POLICY IF EXISTS "Users can view own notes" ON public.notes;
    DROP POLICY IF EXISTS "Users can insert own notes" ON public.notes;
    DROP POLICY IF EXISTS "Users can update own notes" ON public.notes;
    DROP POLICY IF EXISTS "Users can delete own notes" ON public.notes;
    DROP POLICY IF EXISTS "Users can view own analytics" ON public.analytics_tag_corrections;
    DROP POLICY IF EXISTS "Users can insert own analytics" ON public.analytics_tag_corrections;
    DROP POLICY IF EXISTS "Users can update own analytics" ON public.analytics_tag_corrections;
    DROP POLICY IF EXISTS "Users can delete own analytics" ON public.analytics_tag_corrections;

    -- 3. DROP ALL EXISTING TABLES
    DROP TABLE IF EXISTS public.analytics_tag_corrections CASCADE;
    DROP TABLE IF EXISTS public.notes CASCADE;

    -- 4. RECREATE TABLES FROM SCRATCH

    -- Enable UUID extension (usually already enabled)
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

    -- Create notes table
    CREATE TABLE public.notes (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        tags TEXT[] DEFAULT '{}',
        frequency_count INTEGER DEFAULT 0,
        last_accessed TIMESTAMPTZ DEFAULT NOW(),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        last_edited TIMESTAMPTZ DEFAULT NOW(),
        title TEXT
    );

    -- Create analytics_tag_corrections table
    CREATE TABLE public.analytics_tag_corrections (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
        note_id UUID,
        note_content TEXT,
        original_tags TEXT[],
        final_tags TEXT[],
        added_tags TEXT[],
        removed_tags TEXT[],
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- 5. CREATE INDEXES

    -- Notes table indexes
    CREATE INDEX idx_notes_user_id ON public.notes(user_id);
    CREATE INDEX idx_notes_last_accessed ON public.notes(last_accessed DESC);
    CREATE INDEX idx_notes_created_at ON public.notes(created_at DESC);
    CREATE INDEX idx_notes_title ON public.notes(title);

    -- Analytics table indexes
    CREATE INDEX idx_tag_corrections_user ON public.analytics_tag_corrections(user_id);
    CREATE INDEX idx_tag_corrections_removed ON public.analytics_tag_corrections USING GIN(removed_tags);
    CREATE INDEX idx_tag_corrections_created ON public.analytics_tag_corrections(created_at DESC);

    -- 6. ENABLE ROW LEVEL SECURITY

    ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.analytics_tag_corrections ENABLE ROW LEVEL SECURITY;

    -- 7. CREATE RLS POLICIES

    -- Notes table policies
    CREATE POLICY "Users can view own notes" 
        ON public.notes 
        FOR SELECT 
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can insert own notes" 
        ON public.notes 
        FOR INSERT 
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can update own notes" 
        ON public.notes 
        FOR UPDATE 
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can delete own notes" 
        ON public.notes 
        FOR DELETE 
        USING (auth.uid() = user_id);

    -- Analytics table policies
    CREATE POLICY "Users can view own analytics" 
        ON public.analytics_tag_corrections 
        FOR SELECT 
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can insert own analytics" 
        ON public.analytics_tag_corrections 
        FOR INSERT 
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can update own analytics" 
        ON public.analytics_tag_corrections 
        FOR UPDATE 
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can delete own analytics" 
        ON public.analytics_tag_corrections 
        FOR DELETE 
        USING (auth.uid() = user_id);

    -- ===========================================
    -- Reset Complete!
    -- ===========================================
