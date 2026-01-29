# NoteFlow

Smart notes app with frequency-based surfacing and AI-powered organization.

## Features (Phase 1)

- **Smart Capture** - Voice-to-text and quick text entry
- **Auto-Tagging** - Rule-based categorization (work, bills, ideas, gifts, etc.)
- **Frequency Tracking** - Learn which notes you actually use
- **Intelligent Home Screen** - Time-based sections (Daily/Weekly/Monthly/Archive)

## Tech Stack

- **Frontend:** Flutter 3.10.4+
- **Backend:** Supabase (PostgreSQL + Auth)
- **Local Storage:** Hive for frequency tracking
- **Design:** Glassmorphism with dark mode

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── config/              # Supabase configuration
│   └── theme/               # Design system
├── models/                   # Data models
├── services/                 # Business logic
│   ├── auth_service.dart
│   ├── supabase_service.dart
│   ├── tagging_service.dart
│   ├── frequency_tracker.dart
│   ├── speech_service.dart
│   └── local_storage_service.dart
├── screens/                  # UI screens
│   ├── splash_screen.dart
│   ├── home_screen.dart
│   ├── voice_capture_screen.dart
│   └── note_detail_screen.dart
└── widgets/                  # Reusable components
    ├── glass_card.dart
    ├── glass_search_bar.dart
    ├── glass_button.dart
    ├── note_card.dart
    ├── tag_chip.dart
    └── breathing_circle.dart

supabase/
└── schema.sql               # Database schema with RLS policies

docs/
└── Github_Issues_Workflow.md  # Two-agent development workflow
```

## License

MIT License - see LICENSE file for details
