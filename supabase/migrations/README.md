# Database Migrations

Migrations are numbered sequentially and applied in order.

## Naming Convention
```
XXX_description.sql
```
- `XXX` = Sequential number (001, 002, 003...)
- `description` = Brief description with underscores

## Examples
- `001_add_favorites_table.sql`
- `002_add_note_categories.sql`
- `003_add_sharing_permissions.sql`

## Workflow

### Development
1. Create migration file in `supabase/migrations/`
2. Run in **DEV** project SQL Editor
3. Test with `flutter run`
4. Commit migration file to git

### Before Release
1. Run migration in **MAIN** project SQL Editor
2. Verify tables exist in dashboard
3. Run `.\build_internal.bat`
4. Upload to Play Console

## Important Notes
- ⚠️ **Always test in DEV first**
- ⚠️ **Run in MAIN before releasing app**
- ⚠️ **App will crash if tables don't exist**
- ✅ Save all schema changes as migration files
- ✅ Commit migration files to git
- ✅ Migrations should be idempotent (use `IF NOT EXISTS`)

## Current Migrations
- `001_add_favorites_table.sql` - (Example only, not applied)
