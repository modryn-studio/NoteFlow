@echo off
echo ========================================
echo Building for INTERNAL TESTING
echo ========================================
echo.

REM Your MAIN project credentials (for internal testers)
set TESTING_URL=https://geiiuwbcpyamkeehbswo.supabase.co
set TESTING_KEY=sb_publishable_w3KPwU1xPjpFIkyYsQMyYQ_0iUeF5Rx

echo Building app bundle with testing environment...
flutter build appbundle --release ^
  --dart-define=ENV=testing ^
  --dart-define=SUPABASE_URL=%TESTING_URL% ^
  --dart-define=SUPABASE_KEY=%TESTING_KEY%

echo.
echo ========================================
echo BUILD COMPLETE!
echo ========================================
echo Upload from: build\app\outputs\bundle\release\app-release.aab
echo.
pause
