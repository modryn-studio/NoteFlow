# NoteFlow

Smart notes app with frequency-based surfacing and AI-powered organization.

## Features (Phase 1)

- 🎤 **Smart Capture** - Voice-to-text and quick text entry
- 🏷️ **Auto-Tagging** - Rule-based categorization (work, bills, ideas, gifts, etc.)
- 📊 **Frequency Tracking** - Learn which notes you actually use
- 🏠 **Intelligent Home Screen** - Time-based sections (Daily/Weekly/Monthly/Archive)

## Tech Stack

- **Frontend:** Flutter 3.10.4+
- **Backend:** Supabase (PostgreSQL + Auth)
- **Local Storage:** Hive for frequency tracking
- **Design:** Glassmorphism with dark mode

## Quick Start

### Prerequisites

- Flutter SDK 3.10.4+
- Supabase account
- Android Studio / Xcode for device testing

### Setup

1. Clone the repository:
```bash
git clone https://github.com/modryn-studio/NoteFlow.git
cd NoteFlow
```

2. Install dependencies:
```bash
flutter pub get
```

3. Create `.env` file in project root:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
```

4. Run Supabase schema:
```sql
-- Execute supabase/schema.sql in your Supabase SQL editor
```

5. Run the app:
```bash
flutter run
```

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

## Development Workflow

This project uses a two-agent system for development:
- **Agent 1 (Claude Desktop):** Creates specs via GitHub MCP
- **Agent 2 (VS Code Copilot):** Implements features

See [docs/Github_Issues_Workflow.md](docs/Github_Issues_Workflow.md) for details.

## Contributing

1. Check open issues or create a new one
2. Follow the two-agent workflow for complex features
3. Ensure tests pass before pushing
4. Reference issue numbers in commit messages

## License

MIT License - see LICENSE file for details
