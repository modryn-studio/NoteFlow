# Quick Start: Upload to Play Console

## 🎯 What You Need
- [ ] Release bundle built: `build/app/outputs/bundle/release/app-release.aab`
- [ ] Phone screenshots (8 images) in `assets/phone_screenshots/`
- [ ] Google Play Console account with NoteFlow app created

## 📤 Upload Steps (5 minutes)

### 1. Go to Internal Testing
```
https://play.google.com/console
→ Select "NoteFlow"
→ Testing → Internal testing
→ Create new release
```

### 2. Upload Bundle
- Click **Upload** button
- Select: `build/app/outputs/bundle/release/app-release.aab`
- Wait for processing (1-2 minutes)

### 3. Add Release Notes
```
Version 1.0.1 - Internal Testing

✨ Features:
- Voice-to-text note capture
- Smart auto-tagging (work, bills, ideas, gifts, etc.)
- Frequency-based organization (Daily/Weekly/Monthly/Archive)
- Search functionality
- Offline support with background sync

🐛 Fixes:
- Improved back button behavior for search
- Fixed race conditions in frequency tracking
- Better error handling
```

### 4. Add Testers
- Click "Create email list" or use existing
- Add your email: `[your-email@example.com]`
- Save

### 5. Roll Out
- Click "Review release"
- Click "Start rollout to Internal testing"
- Done! ✅

## 📱 Install on Your Phone

### Method 1: Play Store Link (Recommended)
1. After rollout completes (~5 minutes)
2. Copy the "Internal testing track link" from Play Console
3. Open on your phone (signed in with tester account)
4. Accept to become a tester
5. Install from Play Store

### Method 2: Direct APK Install
```powershell
# Build APK
flutter build apk --release

# Connect phone via USB
# Enable USB debugging in Developer Options

# Install
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 🔄 For Future Updates

1. Increment version in `pubspec.yaml`:
   ```yaml
   version: 1.0.2+5  # increment build number
   ```

2. Rebuild:
   ```powershell
   flutter build appbundle --release
   ```

3. Upload to same Internal testing track
4. Testers get automatic update

## ⚠️ Common Issues

**"Upload failed - duplicate version"**
- Increment build number in `pubspec.yaml`
- Rebuild

**"App not signed correctly"**
- Check `android/key.properties` exists
- Verify keystore file path is correct

**"Testers can't see the app"**
- Make sure they accepted the tester invitation email
- Check they're signed in with the correct Google account

**"App crashes on launch"**
- Check if .env file secrets are configured
- Review Android vitals in Play Console for crash reports

## 📊 Monitor

After testers install:
- **Play Console** → **Quality** → **Android vitals**
- Check for crashes, ANRs, battery drain
- Review pre-launch reports

## 🎉 Success Criteria

App is ready for wider testing when:
- [ ] No crashes in normal usage
- [ ] All core features work
- [ ] Performance is smooth (no lag)
- [ ] Battery usage is reasonable
- [ ] Works offline as expected
