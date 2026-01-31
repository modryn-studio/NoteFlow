# NoteFlow Release Checklist - Internal Testing

## ✅ Pre-Release Setup (Completed)

- [x] Signing keys configured (`android/key.properties`)
- [x] App version updated to `1.0.1+4` in `pubspec.yaml`
- [x] Build files cleaned (`flutter clean`)
- [x] Release bundle building (`flutter build appbundle --release`)

## 📦 Build Artifacts

**Release App Bundle Location:**
```
build/app/outputs/bundle/release/app-release.aab
```

**File to upload to Google Play Console:** `app-release.aab`

## 🚀 Google Play Console Setup

### Step 1: Create Internal Testing Track
1. Go to [Google Play Console](https://play.google.com/console)
2. Select **NoteFlow** app
3. Navigate to: **Testing** → **Internal testing**
4. Click **Create new release**

### Step 2: Upload App Bundle
1. Click **Upload** under "App bundles"
2. Select: `build/app/outputs/bundle/release/app-release.aab`
3. Wait for upload and processing (may take a few minutes)

### Step 3: Release Details
1. **Release name:** `1.0.1 (4)` (auto-filled from bundle)
2. **Release notes:** 
   ```
   Initial internal testing release
   
   New Features:
   - Voice-to-text note capture
   - Smart auto-tagging
   - Frequency-based organization
   - Offline support with background sync
   - Search functionality
   
   Improvements:
   - Fixed back button behavior for search
   - Improved error handling and race condition prevention
   - Better resource cleanup
   ```

### Step 4: Add Testers
1. Scroll to "Testers" section
2. Click **Create email list** or select existing list
3. Add tester emails (your email and team members)
4. Click **Save**

### Step 5: Review and Roll Out
1. Review the release summary
2. Click **Review release**
3. Click **Start rollout to Internal testing**
4. Confirm rollout

## 📱 Installing on Your Device

### Option A: Google Play Console Link (Recommended)
1. After rollout, go to **Internal testing** tab
2. Copy the **Internal testing track link**
3. Open link on your phone (while logged in with tester account)
4. Click **Download** or **Install**
5. Accept to become a tester
6. Install the app from Play Store

### Option B: Direct Install (if you need immediate access)
1. Build APK: `flutter build apk --release`
2. APK location: `build/app/outputs/flutter-apk/app-release.apk`
3. Transfer to phone and install (enable "Install from unknown sources")

## 🧪 Testing Checklist

### Core Features
- [ ] Voice capture works (microphone permission granted)
- [ ] Text note creation works
- [ ] Auto-tagging assigns correct tags
- [ ] Notes appear in correct frequency categories (Daily/Weekly/Monthly/Archive)
- [ ] Search functionality works
- [ ] Back button behavior (close keyboard → clear search → close app)
- [ ] Note editing and saving
- [ ] Note deletion
- [ ] Bulk delete (multi-select)
- [ ] Offline mode (airplane mode test)
- [ ] Background sync when back online

### UI/UX
- [ ] Dark mode looks good
- [ ] Glassmorphism effects render correctly
- [ ] No UI glitches or overlapping elements
- [ ] Smooth animations
- [ ] Loading states display correctly

### Performance
- [ ] App launches quickly (< 3 seconds)
- [ ] No crashes during normal use
- [ ] Scrolling is smooth
- [ ] Voice recognition is responsive
- [ ] Search is fast

### Edge Cases
- [ ] Empty notes list state
- [ ] Very long note content
- [ ] Many tags on a single note
- [ ] Slow network conditions
- [ ] App backgrounding and resuming

## 📊 Monitor

After testers install:
1. Check **Google Play Console** → **Quality** → **Android vitals**
2. Monitor crash reports
3. Review feedback from testers
4. Check performance metrics

## 🔄 Next Steps

After internal testing is successful:
1. Fix any issues found
2. Increment version: `1.0.2+5` in `pubspec.yaml`
3. Build new release
4. Move to **Closed testing** (alpha/beta)
5. Eventually promote to **Production**

## 📝 Notes

- **Version naming:** `major.minor.patch+buildNumber`
  - Currently: `1.0.1+4`
  - Increment build number (+1) for each upload
  - Increment version for feature changes
  
- **Internal testing** allows up to 100 testers
- Changes go live immediately (no review needed)
- Perfect for quick iterations

## 🔗 Useful Links

- [Play Console](https://play.google.com/console)
- [App Bundle format](https://developer.android.com/guide/app-bundle)
- [Internal testing docs](https://support.google.com/googleplay/android-developer/answer/9845334)
