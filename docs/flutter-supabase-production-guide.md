# Complete Flutter + Supabase Production Workflow
## From Development to Play Store

**This guide is optimized for solo developers shipping their first Play Store app with Flutter + Supabase using a Google Play organization account.**

> **Note:** This guide assumes you're registering as an organization (LLC). Organization accounts can submit directly to production **after verification**, though Google may still temporarily gate production access on first app submission if additional trust signals are required (this does not require closed testing). Personal developer accounts (created after November 2023) must complete 14 days of closed testing with at least 20 testers before production access.

---

## 🚀 QUICK START (Solo Developer Path)

Overwhelmed? **Start here.** You can come back to the details later.

### Your First Day
```dart
// 1. Put your Supabase keys directly in code (RLS will protect your data)
// lib/core/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// main.dart
await Supabase.initialize(
  url: 'https://your-project.supabase.co',
  anonKey: 'your-anon-key',
  debug: true, // Shows helpful logs (may change in future SDK versions)
);
```

```bash
# 2. Test on your phone
flutter run

# 3. Make changes and hot reload
r  # Instant updates
```

### Timeline Expectations (Organization Account)

**From ready-to-submit to live:**
- Setup keystore: 30 minutes (one-time)
- Optional internal testing: 2-3 days (recommended for your own confidence)
- Organization verification: 1-3 days (one-time, before first app)
- Play Store submission: 1-3 days (Google review)
- **Total: ~1 week after your app is ready (or 3-5 days if skipping internal testing)**

**For updates:**
- Code changes: Minutes to hours (your pace)
- Test: 1 day
- Submit: Same day
- Goes live: Next day or same day

### When You're Ready for Production

**Minimum Requirements (Organization Account):**
1. Organization account verified (D-U-N-S number, LLC docs - one-time setup)
2. App works on your phone
3. App works on second phone
4. No crashes during basic use
5. Privacy policy URL (see Phase 3)
6. Keystore generated (see below)

**Organization Account Advantage:** No mandatory 14-day testing period. You can submit directly to production after verification. Internal testing is still recommended for your own confidence, but not required by Google.

That's it. Everything else can be fixed in updates.

**Skip everything else until you need it.** The rest of this guide is reference material for when issues arise or you want to scale up.

---

## PRE-PHASE: Initial Project Setup (Do Once)

### 1. Supabase Project Configuration

#### Solo Developer Phase (Start Here)

**Use ONE Supabase project for everything initially.** This works for:
- ✅ Testing on your phone
- ✅ Testing on a separate phone
- ✅ 5-10 beta testers
- ✅ Even early production (< 100 users)

```dart
// lib/core/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// main.dart
await Supabase.initialize(
  url: 'https://your-project.supabase.co',
  anonKey: 'your-anon-key',
  debug: kDebugMode, // Auto-enables logging in debug only (may change in future SDK versions)
);
```

**Why this is safe:**
- Row Level Security (RLS) policies protect data (see Supabase Production Config section)
- Even if you accidentally push to production, RLS prevents data leaks
- One project = simpler, no environment switching confusion

#### Internal Testing Setup: Separate Dev/Main Projects

**When doing internal testing**, use two Supabase projects (both free tier):
- **DEV project**: Your local debugging (`flutter run`)
- **MAIN project**: Internal testers' builds

This prevents your test data from mixing with testers' data.

**Setup:**

1. **Create dev project** at supabase.com
   - Name: `yourapp-dev`
   - Copy URL and anon key

2. **Update your code** (lib/core/config/supabase_config.dart):
```dart
class SupabaseConfig {
  static String get supabaseUrl {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw SupabaseConfigException('SUPABASE_URL not configured');
    }
    return url;
  }

  static String get supabaseKey {
    const envKey = String.fromEnvironment('SUPABASE_KEY');
    if (envKey.isNotEmpty) return envKey;
    
    final key = dotenv.env['SUPABASE_KEY'];
    if (key == null || key.isEmpty) {
      throw SupabaseConfigException('SUPABASE_KEY not configured');
    }
    return key;
  }

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  }
}
```

3. **Create .env file** (dev project credentials):
```bash
# .env (gitignored)
SUPABASE_URL=https://your-dev-project.supabase.co
SUPABASE_KEY=your-dev-anon-key
```

4. **Create build_internal.bat** (main project credentials):
```batch
@echo off
set MAIN_URL=https://your-main-project.supabase.co
set MAIN_KEY=your-main-anon-key

flutter build appbundle --release ^
  --dart-define=SUPABASE_URL=%MAIN_URL% ^
  --dart-define=SUPABASE_KEY=%MAIN_KEY%

echo Upload: build\app\outputs\bundle\release\app-release.aab
pause
```

5. **Copy schema to dev project**:
   - Run your `schema.sql` in dev project SQL Editor
   - Enable Anonymous Sign-in in both projects

**Schema Changes Workflow:**

When adding tables/columns:

1. Create migration file: `supabase/migrations/001_add_feature.sql`
2. Run in **DEV** project → test with `flutter run`
3. When ready to release:
   - Run migration in **MAIN** project SQL Editor
   - Verify tables exist
   - Update pubspec.yaml version
   - Run `build_internal.bat`
   - Upload to Play Console

**Daily workflow:**
- `flutter run` → uses .env → DEV project
- `build_internal.bat` → uses --dart-define → MAIN project

**Alternative:** Pay for Supabase Pro ($25/month) to use branches instead of separate projects.

### 2. Android Release Signing Setup (One-Time)

#### Generate Keystore (if you haven't)
```bash
cd android/app

keytool -genkey -v -keystore noteflow-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias noteflow

# Answer prompts:
# - Password: SAVE THIS SECURELY
# - Name, org, location, etc.
```

#### Create key.properties
```bash
# android/key.properties (NEVER commit to git!)
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=noteflow
storeFile=/Users/yourname/projects/noteflow/android/app/noteflow-release-key.jks
```

#### Update .gitignore
```
# android/.gitignore
key.properties
*.jks
*.keystore
```

#### Configure android/app/build.gradle.kts
```kotlin
// Add before android block
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    // ... existing config ...
    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            
            // Disable minification for Flutter apps with Supabase/JSON serialization
            // R8 obfuscation can break JSON parsing, and APK size increase is minimal (1-3 MB)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}
```

**Why disable minification?** Flutter apps are already compiled to native code. R8/ProGuard only affects the small Android wrapper layer. For apps using JSON serialization (Supabase, Firebase, etc.), minification often breaks field name mapping, causing silent failures in release builds. The APK size increase (~1-3 MB) is negligible compared to debugging cryptic release-only bugs.

### 3. App Configuration

#### AndroidManifest.xml Setup
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    
    <application
        android:label="Your App Name"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Deep linking for auth -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop">
            
            <!-- Regular launcher -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            
            <!-- Deep links for Supabase auth -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <!-- Replace with your package name -->
                <data android:scheme="com.yourapp.noteflow" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

#### pubspec.yaml Version Management
```yaml
name: noteflow
description: A new Flutter project.
publish_to: 'none'

# VERSION FORMAT: major.minor.patch+buildNumber
# - First number (1.0.0): Breaking changes
# - Second number (1.1.0): New features
# - Third number (1.0.1): Bug fixes
# - Build number (+1, +2): Increments with EVERY upload to Play Store

version: 1.0.0+1  # Initial release

# For first update:
# version: 1.0.1+2  # Bug fix
# version: 1.1.0+2  # New feature
# version: 2.0.0+2  # Breaking change
```

---

## PHASE 1: Development & Debug Testing

### Flow 
```bash
flutter analyze                    # Check for errors
flutter devices                    # Verify devices connected

# Start development
flutter run                        # Deploy to connected device
# Test on your phone
# Test on separate phone

# Making changes
r                                  # Hot reload (instant updates)
R                                  # Hot restart (full restart)
ctrl+c                            # Stop the app
```

### Debug Best Practices

#### Logging

Use `debugPrint()` for logging - it's automatically disabled in release builds:

```dart
import 'package:flutter/foundation.dart';

// In your code
debugPrint('User logged in');
debugPrint('Error: $error');

// Or check if in debug mode
if (kDebugMode) {
  print('Debug info: $someVariable');
}
```

**Supabase debug mode** is already enabled from Quick Start setup (using `debug: kDebugMode`).

#### Test Auth Methods
```dart
// Email/Password
await supabase.auth.signUp(
  email: email,
  password: password,
);

// Magic Link
await supabase.auth.signInWithOtp(
  email: email,
  emailRedirectTo: 'com.yourapp.noteflow://auth',
);

// Anonymous
await supabase.auth.signInAnonymously();

// OAuth (future - placeholder)
await supabase.auth.signInWithOAuth(
  Provider.google,
  redirectTo: 'com.yourapp.noteflow://auth',
);
```

#### Testing on Multiple Devices

Test the basics on both phones:
- **Login/signup** works
- **Core features** function (create, read, update, delete)
- **Data syncs** between devices

That's it. You'll naturally discover other issues through normal use.

---

## PHASE 2: Internal Testing Track (Optional for Both Account Types)

### Why Use Internal Testing?

**For Organization Accounts:** Internal testing is completely optional. You can publish directly to production after verification.

**For Personal Accounts:** Closed testing is required for 14 days with 20+ testers before production access. Internal testing is one way to satisfy this requirement.

> **Note:** Internal testing does **not** count as closed testing unless explicitly configured as a closed track.

**Why you should still consider internal testing (either account type):**
- ✅ Signed by Google (production signing)
- ✅ Installed via Play Store (real user experience)
- ✅ Tests update flow when you push new versions
- ✅ Tests on real Play Store infrastructure
- ✅ Easy sharing with family/beta testers via link
- ✅ Catches issues before public release
- ✅ Builds confidence before going live publicly

**Perfect for solo developers** who want to test with family/friends before going public. **Skip this if you're confident** and want to launch immediately.

### Setup Internal Testing (One-Time)

#### 1. Go to Google Play Console
```
play.google.com/console
→ Select your app
→ Testing → Internal testing
→ Create new release
```

#### 2. Add Testers
```
→ Testers tab
→ Create email list: "Family/Friends Testers"
→ Add emails:
   - your@email.com
   - other@email.com
→ Save
```

#### 3. Build and Upload
```bash
# If using separate dev/main projects:
# Run build_internal.bat (uses main project)
.\build_internal.bat

# OR if single project:
# flutter build appbundle --release

# File location
build/app/outputs/bundle/release/app-release.aab

# Upload to Internal Testing
→ Google Play Console
→ Internal testing → Create new release
→ Upload app-release.aab
→ Release name: "Initial Release"
→ Release notes: "First version for family testing"
→ Review and roll out
```

#### 4. Install on Devices
```
→ Copy the opt-in link from Play Console
→ Send to your wife
→ Both click link → Become a tester
→ Download app from Play Store
→ Test like a real user
```

### Internal Testing Checklist
```
First Install (Both Devices):
[ ] App installs from Play Store
[ ] Login/signup works
[ ] All features function
[ ] No crashes

24 Hours Later:
[ ] App still works after reboot
[ ] Data persists
[ ] Background sync works

After Making an Update:
[ ] Update downloads automatically
[ ] Data persists after update
[ ] New features work
[ ] Old data still accessible
```

---

## ✅ IS MY APP READY FOR PRODUCTION?

**Organization Account Checklist:**

```
[ ] Organization account verified (one-time: D-U-N-S, LLC docs)
[ ] App doesn't crash on my phone
[ ] App doesn't crash on second phone (wife/friend)
[ ] Login/signup works
[ ] Core features work (create, edit, view, delete)
[ ] Data syncs between phones
[ ] Privacy policy URL exists and loads
[ ] App icon looks good
[ ] Screenshots prepared (at least 2)
```

**That's it.** With an org account, you can submit directly to production once verified. No mandatory closed testing period.

**Personal Account:** If using a personal account instead, you must complete 14 days of closed testing with 20+ active testers before production access becomes available.

**Optional but recommended (both account types):** Test via Internal Testing track for 2-3 days for added confidence before public launch.

---

## PHASE 2.5: Organization Account Setup (One-Time, Before First App)

**If you haven't set up your organization account yet**, you'll need to complete this before your first production submission:

### Organization Account Requirements

1. **Legal Entity Formation**
   - Form a Wisconsin LLC (~$130, same-day approval online)
   - Get stamped Articles of Organization from Department of Financial Institutions
   - Annual maintenance: $25 annual report

2. **D-U-N-S Number** (Start this first - takes longest)
   - Apply at dnb.com/duns/get-a-duns.html (free)
   - Takes up to 30 days to process
   - Must match LLC name exactly

3. **EIN (Employer Identification Number)**
   - Apply at irs.gov/EIN (free, instant)
   - Get CP 575 confirmation letter
   - Apply after LLC is formed

4. **Website Verification**
   - Verify your domain in Google Search Console
   - Website should show business name and contact info

5. **Create Organization Developer Account**
   - Use new Google account (separate from personal)
   - Select "Organization" account type
   - Enter D-U-N-S number in Google Payments profile
   - Upload verification documents: Articles of Organization, EIN letter
   - Upload government ID (color photo)
   - Pay $25 registration fee

6. **Wait for Verification**
   - Typically 1-3 days
   - Google reviews your documents
   - Once approved, you can publish immediately

**Timeline:** 4-5 weeks total (mostly waiting for D-U-N-S number)

**Total Cost:** $155 one-time ($130 LLC + $25 Google Play)

---

## PHASE 3: Production Submission

### Pre-Submission Checklist

#### 1. App Store Listing Requirements

**Store Presence → Main Store Listing**
```
App Name: [Your App Name] (30 characters max)

Short Description: (80 characters)
"Simple note-taking for families. Sync across devices."

Full Description: (4000 characters)
Write compelling description covering:
- What problem it solves
- Key features
- Why users should download
- Privacy commitment

Add:
- 2-8 screenshots (phone + tablet)
- Feature graphic (1024x500)
- App icon (512x512)
```

#### 2. Privacy Policy (REQUIRED) - 5 Minute Solution

You MUST have a publicly accessible privacy policy URL before submitting to Play Store.

**Option 1: Free Generator (Fastest - 3 minutes)**
```
1. Go to https://www.freeprivacypolicy.com/free-privacy-policy-generator/
2. Fill in:
   - App name
   - Your email
   - Select "Mobile App"
   - Add "Supabase" as third-party service
3. Click Generate
4. Copy the generated URL
5. Paste into Play Console → App Content → Privacy Policy
```

**Option 2: GitHub Pages (DIY - 5 minutes)**

**Option A: Using your existing NoteFlow repo (easiest)**
If you already have a `docs/privacy-policy.html` file:

```bash
1. Go to your NoteFlow repo → Settings → Pages
2. Source: "Deploy from a branch"
3. Branch: main → /docs folder
4. Save

Your URL will be:
https://modryn-studio.github.io/NoteFlow/privacy-policy.html

5. Add this URL to Play Console → App Content → Privacy Policy
```

**Option B: Separate privacy policy repo**
```html
<!-- Create privacy.html file -->
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Privacy Policy - YourApp</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
    h1 { color: #333; }
  </style>
</head>
<body>
  <h1>Privacy Policy for YourApp</h1>
  <p><strong>Last updated:</strong> January 27, 2026</p>
  
  <h2>Data We Collect</h2>
  <p>• Email addresses (for account login and authentication)</p>
  <p>• User-generated content (notes, tasks, etc.)</p>
  
  <h2>How We Use Your Data</h2>
  <p>• Authentication and account management</p>
  <p>• Syncing your data across devices</p>
  <p>• We do NOT sell or share your data with third parties</p>
  
  <h2>Third-Party Services</h2>
  <p>We use Supabase for backend database and authentication.</p>
  
  <h2>Your Rights</h2>
  <p>• You can request data deletion at any time</p>
  <p>• You can export your data</p>
  <p>• Data is encrypted in transit</p>
  
  <h2>Contact</h2>
  <p>Email: youremail@example.com</p>
</body>
</html>
```

```bash
# Upload to GitHub
1. Create new repo (e.g., "noteflow-privacy")
2. Rename privacy.html to index.html (for clean URL)
3. Go to Settings → Pages
4. Enable Pages from main branch
5. Your URL: https://yourusername.github.io/noteflow-privacy/
6. Paste this URL into Play Console
```

#### 3. Data Safety Form (CRITICAL)
```
Play Console → App Content → Data Safety

"Does your app collect or share user data?"
→ YES

Data types collected:
→ Personal info → Email address
   ✓ Collected
   ✓ Required (for account management)
   ✗ NOT shared with third parties
   ✓ Encrypted in transit
   ✓ User can request deletion

→ App activity → User-generated content
   ✓ Collected
   ✗ Optional
   ✗ NOT shared with third parties
   ✓ Encrypted in transit
   ✓ User can request deletion

Security practices:
✓ Data is encrypted in transit
✓ Data is encrypted at rest
✓ Users can request data deletion
✓ Not subject to Families Policy (18+ audience)
```

#### 4. Content Rating
```
→ App Content → Content ratings
→ Start questionnaire

Family app answers:
- Does NOT contain violence
- Does NOT contain sexual content
- Does NOT contain language
- Does NOT reference drugs/alcohol
- Is NOT a gambling app
- Does NOT contain user-generated content visible to all users
  (if private notes only)

Rating: Everyone / PEGI 3
```

#### 5. Target Audience

⚠️ **IMPORTANT: Selecting under-13 triggers strict Families Policy compliance (COPPA).**

**Safest for solo developers:**
```
→ Target audience and content
→ Age: 18+
→ Description: "Designed for adults managing family tasks"
```

**This avoids:**
- COPPA compliance requirements
- Restricted ads/analytics
- Additional content reviews
- Families Policy enforcement

**If you must target children (under 13):**
```
→ Check: Ages 5-12, Ages 13-17

Requirements:
- Must comply with COPPA
- No third-party analytics (unless family-safe certified)
- No ads (or only family-safe certified ads)
- Additional Play Store review scrutiny
- Teacher/parent verification features
```

💡 **Tip:** You can always expand audience later. Start with 18+ for your first release.

#### 6. App Access (Testing Credentials)
```
→ App access

For family app with email auth:
→ "All features are available without restrictions"
→ No demo credentials needed

⚠️ If you had OAuth or special features:
→ Provide test account
→ List restricted features
```

### Release Build Process (Your Flow + Details)

#### Clean Build
```bash
# 1. Update version
# pubspec.yaml
version: 1.0.0+1  # First release

# 2. Clean previous builds
flutter clean
flutter pub get

# 3. Analyze code
flutter analyze

# 4. Run tests (if you have any)
flutter test

# 5. Build app bundle
flutter build appbundle --release

# Output location
build/app/outputs/bundle/release/app-release.aab
```

#### Upload to Production
```
Google Play Console
→ Production
→ Create new release
→ Upload app-release.aab

Release name: "Version 1.0.0"

Release notes (for users):
"
Initial release! 🎉

Features:
• Create and edit notes
• Sync across your devices
• Email login for family sharing
• Clean, simple interface

We'd love your feedback!
"

→ Review release
→ Start rollout to Production (100%)

**For your first release**, just release to 100%. Staged rollouts (10%, 50%, etc.) are useful when you have 1000+ users, not when you're starting out.
```

### Review Timeline (What to Expect)
```
First App Submission:
- Upload: Instant
- "Pending review": 1-3 days
- "Approved" or "Rejected": Email notification

If Rejected:
- Read email carefully
- Common issues:
  * Privacy policy missing/broken
  * Data safety form incomplete
  * Content rating wrong
  * Screenshots misleading
- Fix issues
- Re-submit (usually faster review)

After Approved:
- App goes live: Within a few hours
- Users can download: Immediately
- Shows in Play Store search: 24-48 hours
```

---

## PHASE 4: Updates (Your Flow Refined)

### Version Number Strategy
```
Current: 1.0.0+1

Bug fix release:
version: 1.0.1+2
- Increment patch (third number)
- Increment build number (after +)

New feature release:
version: 1.1.0+3
- Increment minor (second number)
- Reset patch to 0
- Increment build number

Breaking changes (rare):
version: 2.0.0+4
- Increment major (first number)
- Reset minor and patch to 0
- Increment build number
```

### Update Workflow
```bash
# 1. Make your changes in code

# 2. Update version in pubspec.yaml
version: 1.0.1+2  # Bug fix example

# 3. Test in debug mode (uses DEV project if using separate projects)
flutter run
# Test changes thoroughly

# 4. If using separate dev/main projects:
# Apply any schema migrations to MAIN project first!
# Run new migration SQL in MAIN project SQL Editor

# 5. Build for internal testing
.\build_internal.bat  # If using separate projects
# OR: flutter build appbundle --release

# 6. Upload to Play Console
→ Internal testing → Create new release
→ Upload app-release.aab
→ Add release notes:
"
Version 1.0.1

What's New:
• Fixed login issue on Android 12
• Improved note sync speed
• Minor UI improvements

Thanks for your feedback!
"

# 7. Roll out to 100%
```

### User Update Experience
```
Auto-update (default):
- Users get update within 24 hours
- No action required
- App updates in background
- Data persists automatically

Manual update:
- User opens Play Store
- Sees "Update available"
- Clicks update
- App updates
- Data persists
```

### Monitoring After Release

**Week 1: Check Play Console daily**
- Crashes & ANRs → Should be < 2% (if higher, investigate immediately)
- User reviews → Respond if helpful
- Installs count

**Week 2+: Check Play Console weekly**
- Crashes still low
- Read new reviews
- Plan next update based on feedback

**Pre-launch report** (automatic):
- Google tests your app before rollout
- Shows crashes on various devices
- Review before releasing

---

## CRITICAL MISSING PIECES: Supabase Production Config

### Row Level Security (RLS) - DON'T SKIP THIS

#### Why RLS Matters
```
Without RLS:
- Any user can read/modify ANY data
- Your wife could see other users' notes
- Malicious users could delete everything

With RLS:
- Users only see their own data
- Database enforces access rules
- Even if your Flutter code has bugs, data is safe
```

#### Setup RLS for Notes App Example
```sql
-- 1. Enable RLS on tables
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 2. Create policies for notes table
-- Users can only see their own notes
CREATE POLICY "Users can view own notes"
  ON notes
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can only insert their own notes
CREATE POLICY "Users can create own notes"
  ON notes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can only update their own notes
CREATE POLICY "Users can update own notes"
  ON notes
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can only delete their own notes
CREATE POLICY "Users can delete own notes"
  ON notes
  FOR DELETE
  USING (auth.uid() = user_id);

-- 3. For family sharing (if needed)
-- Allow shared notes
CREATE POLICY "Users can view shared notes"
  ON notes
  FOR SELECT
  USING (
    auth.uid() = user_id 
    OR 
    shared_with @> ARRAY[auth.uid()]::uuid[]
  );
```

### Supabase Auth Configuration

#### Email Templates (Magic Link, etc.)
```
Supabase Dashboard
→ Authentication
→ Email Templates

Confirm signup:
Subject: "Welcome to [Your App]!"
Body: Customize with your branding

Magic Link:
Subject: "Your login link for [Your App]"
Body: Keep it simple and clear

Password Reset:
Subject: "Reset your password"
Body: Add app name and support contact
```

#### Auth Settings
```
→ Authentication → Settings

Site URL: 
- Development: http://localhost
- Production: https://yourapp.com (if you have one)
  OR com.yourapp.noteflow:// (deep link)

Redirect URLs (whitelist):
- com.yourapp.noteflow://auth

Email Auth:
✓ Enable email confirmations (recommended)
✓ Enable email change confirmations
✓ Secure email change (requires re-authentication)

Session:
- JWT expiry: 3600 seconds (1 hour) default
- Refresh token expiry: 2592000 seconds (30 days)
```

### Database Backups (DON'T LOSE DATA)
```
Supabase Dashboard
→ Database
→ Backups

Free tier: Daily backups, 7 days retention
Pro tier: Daily backups, 30 days retention

⚠️ Set up manual backup script:
```

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Backup database
supabase db dump -f backup-$(date +%Y%m%d).sql --project-ref your-project-ref

# Restore manually (production-safe)
psql -h your-db-host -U postgres -d postgres -f backup-20240127.sql

# ⚠️ Never run `supabase db reset` against a production project - it WILL WIPE DATA
```

---

## TROUBLESHOOTING GUIDE (Common Issues)

### Issue: "App not signed correctly"
```
Error: Upload key doesn't match
Solution:
1. Check key.properties paths
2. Verify keystore password
3. Ensure you're using same .jks file
4. Don't regenerate keystore (you'll lose ability to update)
```

### Issue: "Release build crashes/fails but debug works"
```
Cause: R8 code shrinking obfuscating JSON field names, breaking Supabase/serialization

Solution (Recommended): Disable minification in build.gradle.kts

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = false
        isShrinkResources = false
    }
}

Why this works:
- Flutter apps are already compiled - minification only affects tiny Android wrapper
- APK size increase is minimal (1-3 MB)
- No complex ProGuard rules to maintain
- JSON serialization just works
- Many production Flutter apps use this approach

Alternative (Advanced): If you MUST use minification (rare for Flutter apps):
1. Create android/app/proguard-rules.pro:

-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes *Annotation*
-keepattributes Signature

2. Enable in build.gradle.kts:

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
}
```

### Issue: "Auth redirect not working in release"
```
Cause: Deep link not configured
Solution:
1. Check AndroidManifest.xml has intent-filter
2. Verify scheme matches Supabase settings
3. Test: adb shell am start -a android.intent.action.VIEW -d "com.yourapp.noteflow://auth"
```

### Issue: "Data not syncing in production"
```
Checklist:
[ ] Using production Supabase URL/key
[ ] RLS policies are set correctly
[ ] Internet permission in AndroidManifest
[ ] Supabase project is active (free tier pauses after inactivity, but production traffic prevents this)
[ ] Check Supabase dashboard logs
```

### Issue: "Users can't update"
```
Play Console issue:
- Check version code incremented
- Verify signing certificate matches
- Users have auto-update enabled
- Update may take 24-48 hours to reach all users
```

---

## COMPLETE WORKFLOW CHEAT SHEET

### Initial Development
```bash
flutter analyze && flutter run
# Test on multiple devices
# Fix bugs
# Repeat until stable
```

### Pre-Release Testing
```bash
# Internal Testing (recommended)
flutter build appbundle --release
# Upload to Internal Testing track
# Test via Play Store on real devices

# Local release test (optional, if you want to verify build works)
flutter build apk --release
flutter run --release --uninstall-first
```

### Production Release
```bash
# Update version
# pubspec.yaml: version: 1.0.0+1

# Clean build
flutter clean && flutter pub get
flutter analyze
flutter build appbundle --release

# Upload build/app/outputs/bundle/release/app-release.aab
# Play Console → Production → Create release
# Add release notes
# Submit for review
# Wait 1-3 days
```

### Updates
```bash
# Update version
# pubspec.yaml: version: 1.0.1+2

flutter clean && flutter pub get
flutter analyze
flutter build appbundle --release

# Upload to Internal Testing (test first)
# Then promote to Production
# Add release notes
# Roll out gradually (10% → 50% → 100%)
```

---

## FILES YOU NEED (Checklist)

```
Your Project:
✓ key.properties (in android/, gitignored)
✓ noteflow-release-key.jks (in android/app/, gitignored)
✓ proguard-rules.pro (in android/app/)
✓ Privacy policy hosted online
✓ App icon (512x512 for Play Store)
✓ Screenshots (2-8 images)
✓ Feature graphic (1024x500)

Supabase:
✓ RLS policies on all tables (CRITICAL - see Supabase Production Config)
✓ Auth email templates configured (optional but nice)
✓ Redirect URLs whitelisted (for magic links/OAuth)

Google Play Console:
✓ App listing complete
✓ Data safety form filled
✓ Content rating received
✓ Internal testing track set up
✓ Tester email list created
```

---

## FINAL TIPS

### Do:
✅ Test on multiple devices before release
✅ Use Internal Testing for real-world testing
✅ Set up RLS before launch
✅ Keep backup of your keystore file
✅ Respond to user reviews
✅ Monitor crash reports

### Don't:
❌ Skip RLS setup
❌ Commit key.properties or .jks to git
❌ Test only in debug mode
❌ Regenerate keystore (can't update app)
❌ Submit without privacy policy
❌ Ignore Play Console pre-launch reports

### Timeline Expectations:

**Organization Account:**
- Organization setup: 4-5 weeks (one-time, mostly D-U-N-S wait)
- Development: Weeks to months (your pace)
- Optional internal testing: 2-3 days (recommended but not required)
- First Play Store review: 1-3 days
- **Total ready-to-live: ~3-7 days after org verification**

**Personal Account (for comparison):**
- Development: Weeks to months (your pace)
- Mandatory closed testing: 14 days with 20+ testers
- First Play Store review: 1-3 days
- **Total ready-to-live: ~17+ days minimum**

**Updates (both account types):**
- Subsequent updates: Same day to 1 day
- User adoption: Gradual, be patient

### Organization Account Benefits:
✅ No mandatory 14-day closed testing period
✅ Can publish to production immediately after verification
✅ Professional business name displayed (not personal info)
✅ Liability protection through LLC structure
✅ Immediate production access for urgent updates

You're ready to ship! 🚀
