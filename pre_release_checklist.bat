@echo off
echo ========================================
echo PRE-RELEASE CHECKLIST
echo ========================================
echo.
echo Before running build_internal.bat:
echo.
echo [ ] 1. Updated version in pubspec.yaml
echo [ ] 2. Tested all changes with 'flutter run' (DEV project)
echo [ ] 3. Checked supabase\migrations\ for new files
echo [ ] 4. Applied ALL new migrations to MAIN project
echo [ ] 5. Verified tables exist in MAIN project dashboard
echo [ ] 6. No breaking changes to existing data
echo.
echo ========================================
echo If all checked, proceed with:
echo    .\build_internal.bat
echo ========================================
echo.
pause
