-- ===========================================
-- NoteFlow Database Schema
-- Run this in the Supabase SQL Editor
-- ===========================================

-- Enable UUID extension (usually already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create notes table
CREATE TABLE IF NOT EXISTS public.notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    tags TEXT[] DEFAULT '{}',
    frequency_count INTEGER DEFAULT 0,
    last_accessed TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON public.notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_last_accessed ON public.notes(last_accessed DESC);
CREATE INDEX IF NOT EXISTS idx_notes_created_at ON public.notes(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only access their own notes

-- Policy: Users can view their own notes
CREATE POLICY "Users can view own notes" 
    ON public.notes 
    FOR SELECT 
    USING (auth.uid() = user_id);

-- Policy: Users can insert their own notes
CREATE POLICY "Users can insert own notes" 
    ON public.notes 
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own notes
CREATE POLICY "Users can update own notes" 
    ON public.notes 
    FOR UPDATE 
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own notes
CREATE POLICY "Users can delete own notes" 
    ON public.notes 
    FOR DELETE 
    USING (auth.uid() = user_id);

-- ===========================================
-- Enable Anonymous Sign-in in Supabase
-- ===========================================
-- Go to Authentication > Providers > Anonymous Sign-In
-- and enable "Allow anonymous sign-ins"
-- ===========================================
