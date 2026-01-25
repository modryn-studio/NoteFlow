# Debugging Steps for Timestamp Bug

## 1. Check Supabase Database

1. Open your Supabase dashboard: https://supabase.com/dashboard
2. Go to your NoteFlow project
3. Click "Table Editor" in left sidebar
4. Click on "notes" table
5. Look at a note that shows "6h ago" in the app
6. Check these columns:
   - `last_accessed`: What timestamp is shown? (Should look like: `2026-01-25 18:30:00+00`)
   - `created_at`: What timestamp is shown?
7. Compare to current time: What is your current local time right now?

**Screenshot what you see and send it to me**

---

## 2. Check Error Logs

### Option A: Using VS Code terminal (while app is running on phone)

In VS Code terminal where you ran `flutter run`, you should see log output. Look for any messages that say:
- "ERROR"
- "Exception"
- "Failed"
- "Frequency tracking"

### Option B: Using `flutter logs` command

1. Make sure your phone is connected and app is running
2. In VS Code, open a new terminal
3. Run: `flutter logs`
4. This will show all console output from your phone
5. Open a note and watch for any error messages

### Option C: Add debug logging (I'll add this to the code)

I'll add temporary debug prints to see exactly what's happening with timestamps.

---

## 3. What We're Looking For

**In Database:**
- Is `last_accessed` being updated when you open notes?
- Is it stored in UTC (ends with `+00`)?

**In Logs:**
- Are there any errors from `trackNoteOpen()`?
- Are there any timezone-related warnings?

**In App Behavior:**
- Does the "6h ago" appear immediately after some action?
- Or does it appear after the app has been open for a while?
