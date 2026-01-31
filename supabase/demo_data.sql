-- ===========================================
-- NoteFlow Demo Data
-- Creates realistic notes across all time categories
-- ===========================================
-- IMPORTANT: Replace '743286b1-6f81-4418-afef-56d0fd520ad5' with actual user UUID from auth.users
-- Get your user ID by running: SELECT id FROM auth.users LIMIT 1;
-- ===========================================

-- Daily Notes (accessed within 24 hours)
INSERT INTO public.notes (user_id, content, tags, frequency_count, last_accessed, last_edited, created_at) VALUES
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Call Dr. Martinez to schedule annual checkup - mentioned new insurance coverage options', ARRAY['personal', 'health'], 5, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '1 day', NOW() - INTERVAL '3 days'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Team standup notes: Sarah working on API integration, Mike debugging the payment flow, need to review PR #234 by EOD', ARRAY['work'], 12, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '5 hours', NOW() - INTERVAL '2 weeks'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Gift idea for Mom''s birthday: That ceramic tea set she mentioned from the farmers market, blue and white pattern', ARRAY['gifts', 'personal'], 3, NOW() - INTERVAL '8 hours', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Grocery list: milk, eggs, bread, coffee, chicken breast, broccoli, pasta, olive oil, bananas', ARRAY['shopping'], 8, NOW() - INTERVAL '12 hours', NOW() - INTERVAL '13 hours', NOW() - INTERVAL '1 day'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Electric bill due Feb 5th - $127.43 - set up autopay reminder', ARRAY['bills'], 2, NOW() - INTERVAL '18 hours', NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'App idea: Voice notes that automatically create calendar events and reminders based on context. Could use NLP to extract dates and action items.', ARRAY['ideas', 'work'], 7, NOW() - INTERVAL '20 hours', NOW() - INTERVAL '2 days', NOW() - INTERVAL '1 week');

-- Weekly Notes (accessed 2-7 days ago)
INSERT INTO public.notes (user_id, content, tags, frequency_count, last_accessed, last_edited, created_at) VALUES
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Car maintenance: oil change scheduled for Feb 10 at Johnson Auto, bring service history booklet', ARRAY['personal'], 4, NOW() - INTERVAL '2 days', NOW() - INTERVAL '3 days', NOW() - INTERVAL '2 weeks'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Q1 project deadlines: Marketing site redesign (Feb 15), API v2 launch (Mar 1), Mobile app beta (Mar 10)', ARRAY['work'], 9, NOW() - INTERVAL '3 days', NOW() - INTERVAL '1 week', NOW() - INTERVAL '3 weeks'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Movie recommendations from Jake: Dune Part 2, Oppenheimer, Past Lives. Check which are on streaming.', ARRAY['personal', 'ideas'], 2, NOW() - INTERVAL '4 days', NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Internet bill $89.99/month - contract ends in March, shop around for better rates. Look at Verizon and Spectrum deals.', ARRAY['bills'], 3, NOW() - INTERVAL '5 days', NOW() - INTERVAL '6 days', NOW() - INTERVAL '1 month'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Birthday party supplies needed: balloons, cake from Sweet Treats Bakery (order 3 days ahead), candles, decorations', ARRAY['shopping', 'personal'], 5, NOW() - INTERVAL '6 days', NOW() - INTERVAL '7 days', NOW() - INTERVAL '8 days'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Learning goals for 2026: Master Flutter animations, learn AI/ML basics, contribute to open source project', ARRAY['ideas', 'personal'], 6, NOW() - INTERVAL '7 days', NOW() - INTERVAL '2 weeks', NOW() - INTERVAL '2 weeks');

-- Monthly Notes (accessed 8-30 days ago)
INSERT INTO public.notes (user_id, content, tags, frequency_count, last_accessed, last_edited, created_at) VALUES
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Password manager setup: Reviewed Bitwarden vs 1Password. Going with Bitwarden for the family plan at $40/year.', ARRAY['work', 'personal'], 3, NOW() - INTERVAL '10 days', NOW() - INTERVAL '1 month', NOW() - INTERVAL '1 month'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Vacation planning: Looking at beach houses in Outer Banks for July. Budget $2500 for week rental, split with Tom and Lisa.', ARRAY['personal', 'ideas'], 8, NOW() - INTERVAL '15 days', NOW() - INTERVAL '16 days', NOW() - INTERVAL '20 days'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Tax documents to gather: W2 from employer, 1099 from freelance work, mortgage interest statement, charitable donations receipts', ARRAY['bills', 'personal'], 5, NOW() - INTERVAL '18 days', NOW() - INTERVAL '20 days', NOW() - INTERVAL '25 days'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Book club reading list: The Ministry for the Future, Project Hail Mary, Tomorrow and Tomorrow and Tomorrow', ARRAY['personal'], 4, NOW() - INTERVAL '22 days', NOW() - INTERVAL '1 month', NOW() - INTERVAL '1 month'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Home improvement ideas: Repaint guest bedroom (light gray), replace kitchen faucet, install smart thermostat, fix squeaky door', ARRAY['personal', 'ideas'], 2, NOW() - INTERVAL '25 days', NOW() - INTERVAL '2 months', NOW() - INTERVAL '2 months'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Subscription audit: Netflix $15.99, Spotify $10.99, Amazon Prime $14.99, Disney+ $7.99. Consider cutting Disney+ if not using.', ARRAY['bills'], 7, NOW() - INTERVAL '28 days', NOW() - INTERVAL '29 days', NOW() - INTERVAL '1 month');

-- Archive Notes (accessed over 30 days ago)
INSERT INTO public.notes (user_id, content, tags, frequency_count, last_accessed, last_edited, created_at) VALUES
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Conference notes from DevCon 2025: Keynote on AI pair programming, workshop on Flutter performance optimization, met Sarah from Google.', ARRAY['work'], 15, NOW() - INTERVAL '35 days', NOW() - INTERVAL '36 days', NOW() - INTERVAL '2 months'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'New Year resolutions: Exercise 3x per week, read 24 books, learn to cook 5 new recipes, limit social media to 30 min/day', ARRAY['personal', 'ideas'], 10, NOW() - INTERVAL '45 days', NOW() - INTERVAL '2 months', NOW() - INTERVAL '2 months'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Recipe saved: Grandma''s chicken soup - whole chicken, carrots, celery, onion, garlic, thyme, bay leaf. Simmer 2 hours.', ARRAY['personal'], 6, NOW() - INTERVAL '50 days', NOW() - INTERVAL '3 months', NOW() - INTERVAL '3 months'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Old phone trade-in: iPhone 12 valued at $200 through Apple Trade In program. Need to backup and reset before sending.', ARRAY['personal'], 4, NOW() - INTERVAL '60 days', NOW() - INTERVAL '3 months', NOW() - INTERVAL '3 months'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Flight booking reference for Vegas trip: Confirmation #ABC123, Southwest Flight 456, Seat 12A, departs 8:45 AM', ARRAY['personal'], 8, NOW() - INTERVAL '70 days', NOW() - INTERVAL '4 months', NOW() - INTERVAL '4 months'),
('743286b1-6f81-4418-afef-56d0fd520ad5', 'Fitness tracker comparison notes: Compared Fitbit, Garmin, Apple Watch. Went with Garmin for battery life and hiking features.', ARRAY['personal', 'shopping'], 5, NOW() - INTERVAL '90 days', NOW() - INTERVAL '4 months', NOW() - INTERVAL '4 months');

-- ===========================================
-- To use this script:
-- 1. Get your user ID: SELECT id FROM auth.users LIMIT 1;
-- 2. Replace ALL instances of '743286b1-6f81-4418-afef-56d0fd520ad5' with your actual UUID
-- 3. Run the entire script in Supabase SQL Editor
-- 4. Refresh your app to see the demo notes
-- ===========================================

-- Quick verification query to see category distribution:
-- SELECT 
--   CASE 
--     WHEN last_accessed > NOW() - INTERVAL '24 hours' THEN 'Daily'
--     WHEN last_accessed > NOW() - INTERVAL '7 days' THEN 'Weekly'
--     WHEN last_accessed > NOW() - INTERVAL '30 days' THEN 'Monthly'
--     ELSE 'Archive'
--   END as category,
--   COUNT(*) as count
-- FROM notes
-- WHERE user_id = '743286b1-6f81-4418-afef-56d0fd520ad5'
-- GROUP BY category
-- ORDER BY 
--   CASE 
--     WHEN category = 'Daily' THEN 1
--     WHEN category = 'Weekly' THEN 2
--     WHEN category = 'Monthly' THEN 3
--     ELSE 4
--   END;
