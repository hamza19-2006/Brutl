# Brutl App — Complete Architecture & Feature Documentation

> A comprehensive Flutter fitness & social tracking application with AI coaching, Firebase backend, real-time chat, step tracking, nutrition logging, workout planning, and social features.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Tech Stack & Dependencies](#tech-stack--dependencies)
3. [Directory Structure](#directory-structure)
4. [Core / Theme System](#core--theme-system)
5. [Entry Point & App Bootstrap](#entry-point--app-bootstrap)
6. [Authentication Flow](#authentication-flow)
7. [Onboarding Flow](#onboarding-flow)
8. [Home Tab](#home-tab)
9. [Workout Tab](#workout-tab)
10. [Shop Tab](#shop-tab)
11. [Chat Tab](#chat-tab)
12. [Settings Hub](#settings-hub)
13. [AI Coach / Elite AI Trainer](#ai-coach--elite-ai-trainer)
14. [Providers (State Management)](#providers-state-management)
15. [Models](#models)
16. [Services](#services)
17. [Widgets (Reusable UI)](#widgets-reusable-ui)
18. [Data Layer (Firestore + Local)](#data-layer-firestore--local)
19. [Firebase Collections Schema](#firebase-collections-schema)
20. [External Integrations](#external-integrations)
21. [Build & Configuration](#build--configuration)

---

## Project Overview

| Property | Value |
|----------|-------|
| **App Name** | Brutl |
| **Framework** | Flutter 3.11+ |
| **Language** | Dart |
| **Backend** | Firebase (Auth, Firestore, Storage, Vertex AI) |
| **Local DB** | Hive + SharedPreferences |
| **State Management** | Provider (ChangeNotifier) |
| **Design System** | Custom dark theme with orange accent (`#FF3D00`) |
| **Target Platforms** | Android, iOS, Web, Windows, macOS, Linux |

**Tagline:** *Train hard. Track harder.*

---

## Tech Stack & Dependencies

### Core Flutter
- `flutter` (SDK)
- `cupertino_icons: ^1.0.8`
- `google_fonts: ^6.2.1` (Poppins)

### State Management
- `provider: ^6.1.5`

### Firebase
- `firebase_core: ^3.13.0`
- `firebase_auth: ^5.5.3`
- `cloud_firestore: ^5.6.7`
- `firebase_vertexai: ^1.5.0` (Gemini AI)
- `firebase_app_check: ^0.3.2+5`
- `firebase_storage: ^12.3.0`

### Local Storage
- `shared_preferences: ^2.5.3`
- `hive: ^2.2.3`
- `hive_flutter: ^1.1.0`

### Health & Sensors
- `pedometer: ^4.0.2` (step counter)
- `permission_handler: ^11.3.1`
- `workmanager: ^0.9.0` (background tasks)

### Charts & UI
- `fl_chart: ^0.70.2` (line/bar charts)
- `percent_indicator: ^4.2.5`
- `flutter_animate: ^4.2.0`
- `cached_network_image: ^3.4.1`

### Auth & Social
- `google_sign_in: ^7.2.0`
- `url_launcher: ^6.3.0`
- `font_awesome_flutter: ^10.8.0`

### AI & Image
- `http: ^1.2.2`
- `image_picker: ^1.1.2`
- `image: ^4.2.0` (image processing)

### PDF Generation
- `pdf: ^3.11.1`
- `path_provider: ^2.1.5`

### Utilities
- `intl: ^0.20.2` (date/time formatting)

### Dev Dependencies
- `flutter_lints: ^6.0.0`
- `flutter_launcher_icons: ^0.13.1`
- `flutter_native_splash: ^2.4.4`

---

## Directory Structure

```
lib/
├── main.dart                          # App entry point, providers, auth gate
├── config/
│   └── secrets.dart                   # API keys (gitignored)
├── core/
│   └── theme/
│       ├── app_colors.dart            # Color tokens
│       ├── app_gradients.dart         # Gradient tokens
│       ├── app_spacing.dart           # Spacing & radius tokens
│       ├── app_text_styles.dart       # Typography scale (Poppins)
│       ├── app_theme.dart             # ThemeData assembly
│       ├── theme_extensions.dart      # BuildContext extensions
│       └── constants/
│           ├── ai_coach.dart          # AI system prompts
│           ├── ai_diet_plan.dart      # Diet plan constants
│           └── ai_workout_plan.dart   # Workout plan constants
├── models/
│   ├── brutl_models.dart              # Exercise, Nutrition, WorkoutSplit models
│   ├── chat_models.dart               # Message, Friend, FriendRequest models
│   ├── user_model.dart                # BrutlUser (canonical user doc)
│   ├── user_data_models.dart          # UserModel, WorkoutPlanModel, ExerciseModel, HomeUiModel
│   └── body_measurement_model.dart    # BodyMeasurement (cm/inch)
├── providers/
│   ├── auth_provider.dart             # BrutlAuthProvider (email, Google)
│   ├── auth_validation_provider.dart  # Login/signup validation UI state
│   ├── brutl_user_provider.dart       # Canonical BrutlUser live sync
│   ├── chat_provider.dart             # Friends, requests, chat rooms
│   ├── health_provider.dart           # StepProvider (pedometer + calories)
│   ├── ai_coach_provider.dart         # Elite AI Coach messages & generation
│   ├── water_provider.dart            # Water intake tracking
│   ├── workout_provider.dart          # Workout splits, weeks, exercises
│   ├── workout_nutrition_provider.dart  # Workout screen nutrition UI state
│   └── nutrition_service.dart         # Singleton: meal/calorie logging
├── services/
│   ├── ai_diet_plan_service.dart      # AI diet plan generation
│   ├── ai_meal_service.dart           # Meal photo analysis (Gemini + DeepSeek)
│   ├── ai_text_meal_service.dart      # Text-based meal analysis
│   ├── background_service.dart        # Workmanager background step sync
│   ├── calorie_history_service.dart   # Weekly calorie/macro history
│   ├── database_service.dart          # Hive + Firestore sync for exercises
│   ├── firebase_bootstrap.dart        # Firebase init + App Check
│   ├── geo_service.dart               # Country detection (ipinfo.io)
│   ├── local_storage_service.dart     # Hive steps_history box
│   ├── meal_analyzer.dart             # Macro parsing helpers
│   ├── settings_calculator_service.dart
│   ├── step_sensor_service.dart       # Raw pedometer math + baseline
│   └── step_service.dart              # StepService singleton (UI-facing)
├── widgets/
│   ├── ask_ai_dialog.dart             # "Ask AI" quick-action dialog
│   ├── biometric_card.dart            # Steps + Calories cards on Home
│   ├── exercise_card_widget.dart      # Exercise display card
│   ├── exercise_editor_sheet.dart     # Add/edit exercise bottom sheet
│   ├── exercise_highlight_card.dart   # Last workout highlight
│   ├── macro_dashboard_card.dart      # Circular macro ring on Workout tab
│   ├── meal_logger_sheet.dart         # Log meal bottom sheet
│   ├── otp_verification_sheet.dart    # OTP input sheet
│   ├── password_input_field.dart    # Reusable password field
│   ├── water_card.dart                # Compact water card (home screen)
│   ├── workout_card_widget.dart       # Workout day card
│   └── workout_day_card.dart          # Day card for workout split
└── Screens/
    ├── auth/
    │   ├── auth_screen.dart
    │   ├── forgot_password_screen.dart
    │   ├── login_screen.dart
    │   └── sign_up_screen.dart
    ├── onboarding/
    │   ├── onboarding_screen.dart       # 7-page profile setup wizard
    │   └── permission_gate_screen.dart  # Activity recognition permission
    ├── home/
    │   └── home_screen_ex_show.dart     # Exercise showcase section
    ├── chat/
    │   ├── ai_chat_screen.dart          # Elite AI Coach chat UI
    │   ├── chat_list_screen.dart        # Friends list + search + AI entry
    │   ├── chat_room_screen.dart        # 1:1 chat room with messages
    │   ├── friend_requests_screen.dart  # Incoming friend requests
    │   ├── share_meal_screen.dart       # Share meal to chat/AI
    │   ├── share_pr_screen.dart         # Share personal record
    │   └── share_workout_screen.dart    # Share workout to chat/AI
    ├── shop/
    │   ├── brutl_products_screen.dart   # Brutl merchandise (Pakistan only)
    │   ├── diet_workout_screen.dart     # AI Diet & Workout Plan generator
    │   └── shop_main_screen.dart        # Shop router (geo-gated)
    ├── settings/
    │   ├── account_settings_screen.dart
    │   ├── blocked_friends_screen.dart
    │   ├── body_measurement_detail_screen.dart
    │   ├── body_measurements_screen.dart
    │   ├── connected_apps_screen.dart   # Spotify integration tile
    │   ├── contact_support_screen.dart   # Email + WhatsApp support
    │   ├── credentials/
    │   │   └── credentials_screen.dart   # Password change
    │   ├── edit_age_screen.dart
    │   ├── edit_body_fat_screen.dart
    │   ├── edit_height_screen.dart
    │   ├── edit_macros_screen.dart
    │   ├── edit_name_screen.dart
    │   ├── edit_steps_screen.dart
    │   ├── edit_username_screen.dart
    │   ├── edit_weight_screen.dart
    │   ├── feedback_screen.dart          # Feedback / Suggestion submission
    │   ├── main_settings_screen.dart     # Settings hub
    │   ├── personal_stats_screen.dart    # Height, weight, age, body fat
    │   ├── subscription_screen.dart
    │   ├── widgets/
    │   │   └── settings_widgets.dart     # Reusable settings tiles
    │   └── workout_settings/
    │       ├── exercise_settings_screen.dart  # Entry point
    │       ├── edit_days_screen.dart          # Rename/clear workout days
    │       ├── rep_ranges_screen.dart         # Compound/isolation rep ranges
    │       └── split_change_screen.dart       # Change workout split
    ├── calories_history_screen.dart      # Weekly calorie + water charts
    ├── day_detail_screen.dart            # Individual day exercise detail
    ├── home_screen.dart                  # Main scaffold + bottom nav + Home tab
    ├── steps_history_screen.dart         # Weekly steps bar chart
    ├── workout_detail_screen.dart        # Workout session detail
    └── workout_screen.dart               # Workout tab (macros + split days)
```

---

## Core / Theme System

### `app_colors.dart` — Semantic Color Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| `backgroundPrimary` | `#0A0A0A` | Page background |
| `backgroundSecondary` | `#111111` | Bottom nav, section containers |
| `backgroundTertiary` | `#1A1A1A` | Cards, primary surfaces |
| `backgroundQuaternary` | `#242424` | Inputs, chips |
| `borderSubtle` | `#1F1F1F` | Barely visible separators |
| `borderDefault` | `#2A2A2A` | Standard card borders |
| `borderStrong` | `#333333` | Focus/active borders |
| `accentPrimary` | `#FF3D00` | Primary brand orange |
| `accentSecondary` | `#FF6B00` | Gradient accent |
| `textPrimary` | `#FFFFFF` | Main text |
| `textSecondary` | `#AAAAAA` | Body/supporting text |
| `textTertiary` | `#666666` | Captions, placeholders |
| `statusSuccess` | `#22C55E` | Success states |
| `statusWarning` | `#F59E0B` | Warning states |
| `statusError` | `#EF4444` | Error states |

### `app_theme.dart` — Material3 Theme Assembly
- Dark theme with `useMaterial3: true`
- Custom `_BrutlFadePageTransitionsBuilder` for fade transitions across all platforms
- Poppins font family via `GoogleFonts`
- Elevated buttons: orange gradient, full-width, 56px height
- Input decorations: filled quaternary background, orange focused border

### `theme_extensions.dart` — Ergonomic Context Access
- `context.brutl.colors` → `AppColorsPalette`
- `context.brutl.spacing` → `AppSpacingScale`
- `context.brutl.radius` → `AppRadiusScale`
- `context.brutl.gradients` → `AppGradientsPalette`
- `context.displayLarge`, `context.headingLarge`, etc. → Typography

---

## Entry Point & App Bootstrap

### `main.dart`

```
main() ──► WidgetsFlutterBinding.ensureInitialized()
     ├──► Future.wait([FirebaseBootstrap.initialize(), Hive.initFlutter()])
     └──► runApp(BrutlAppBootstrap)
```

**`BrutlAppBootstrap`** registers 8 `ChangeNotifierProvider`s:
1. `BrutlAuthProvider`
2. `AuthValidationProvider`
3. `WorkoutProvider`
4. `StepProvider`
5. `WorkoutNutritionProvider`
6. `BrutlUserProvider`
7. `ChatProvider`
8. `AiCoachProvider`
9. `WaterProvider`

**`AppWarmupGate`** — Two-phase startup optimization:
- **Phase 1 (parallel, disk-only):** Open Hive `exercises` box, init step service, load water data
- **Phase 2 (parallel, Firestore):** Init step provider, workout provider, nutrition provider, bind BrutlUser
- **Lifecycle observer:** On app resume, refreshes steps, checks new-day reset for steps & water

**`AuthWrapper`** — Auth-to-routing gate:
- Listens to `FirebaseAuth.instance.authStateChanges()`
- 8-second watchdog timer prevents infinite loading
- Cache-first profile load, then server refresh
- Incomplete profile → `OnboardingScreen`
- Complete profile → `HomeScreen`
- No user → `LoginScreen`

---

## Authentication Flow

### Login (`login_screen.dart`)
- Email + password login
- Google Sign-In with `google_sign_in`
- Password visibility toggle via `AuthValidationProvider`
- Forgot password link (navigates to reset screen)
- After login: pre-fetches `WorkoutProvider` + `BrutlUserProvider` before navigation

### Sign Up (`sign_up_screen.dart`)
- Email + password registration
- Full name, username, phone number fields
- OTP verification sheet
- On success → `OnboardingScreen`

### Forgot Password (`forgot_password_screen.dart`)
- Firebase `sendPasswordResetEmail()`
- Email validation

### Auth Provider (`auth_provider.dart`)
- `BrutlAuthProvider` manages:
  - Email/password sign-in
  - Google sign-in (with `GoogleAuthResult` for success/cancelled/failure)
  - Sign out (Firebase + Google)
  - Password reset email
  - Country code auto-detection via `GeoService` on registration

---

## Onboarding Flow

### `onboarding_screen.dart` — 7-Page Wizard

| Page | Content |
|------|---------|
| 1 | Identity: display name, username (unique check), gender |
| 2 | Biometrics: height (cm/ft-in), weight (kg/lbs), age, body fat % (with visual reference image) |
| 3 | Workout Split: choose template (PPL, Bro Split, Upper/Lower, etc.) or customize days |
| 4 | Preferences: compound rep range (4-8), isolation rep range (8-12) |
| 5 | Goals & Activity: daily step goal, body goal (Loss/Gain/Maintenance) |
| 6 | Macros: target calories, protein, carbs, fats (auto-calculated from BMR/TDEE) |
| 7 | Review & Save |

**Calculations:**
- BMR: Mifflin-St Jeor equation (or Katch-McArdle if body fat known)
- TDEE: BMR × activity multiplier (based on step goal)
- Goal calories: TDEE ± deficit/surplus
- Protein: `weightKg × 2.0g`
- Fat: `weightKg × 0.7g`
- Carbs: remaining calories / 4

**Persistence:**
- Writes full `BrutlUser` to Firestore `users/{uid}`
- Saves goals to SharedPreferences
- Sets `is_profile_complete: true`

---

## Home Tab

### Layout (`home_screen.dart`)
```
CustomScrollView
├── _HomeHeader
│   ├── Greeting (Good Morning/Afternoon/Evening) + display name
│   ├── Date (EEEE, d MMMM y)
│   ├── Today's split name
│   └── Brutl logo + live calories burned
├── _StatsRow
│   ├── LEFT: StepsCard (big) + WaterCard (compact below)
│   └── RIGHT: CaloriesCard (tall, tappable → history)
├── "Today's Targets" section label
└── HomeScreenExShow (exercise showcase)
```

### Key Features
- **Live Steps:** `StepProvider` streams from `StepSensorService`
- **Live Calories Burned:** `stepCount × 0.04 × (weight/70)`
- **Calories Eaten:** Streamed from `NutritionService`
- **Water Tracking:** Compact card with progress bar, opens bottom sheet
- **Today's Workout:** Pulled from `WorkoutProvider.customSplitDays` based on weekday

---

## Workout Tab

### `workout_screen.dart`

**Layout:**
```
Column
├── Title: "Workout"
├── MacroDashboardCard (circular ring: carbs/protein/fats)
├── Week selector (Week 1–4, horizontal pills)
└── ListView of WorkoutDayCards
    └── Each day → WorkoutCardWidget → tap → DayDetailScreen
```

**Macro Dashboard:**
- Circular progress ring with 3 macro segments
- Tap opens `_MealSelectionSheet`
- Goals sourced from `BrutlUser` (target macros), falls back to weight-based estimates

**Meal Logging:**
- Photo-based AI scan (`ai_meal_service.dart` — Gemini Flash + DeepSeek fallback)
- Manual text entry
- Meal items with calorie/macro breakdown
- Streamed to `NutritionService` which broadcasts to all listeners

**Week System:**
- Auto-computes current week based on `program_start_date` (loops every 4 weeks)
- User can manually override week selection
- Exercises persist per `weekId/dayId` in Firestore + SharedPreferences cache

**Workout Cards:**
- `WorkoutCardWidget` — displays day name, exercise list, "Start" button
- Tapping navigates to `DayDetailScreen` for full exercise management
- Supports importing previous week's exercises

---

## Shop Tab

### `shop_main_screen.dart`
- Geo-gated: shows "Brutl Products" only for Pakistan users (`country == 'Pakistan'`)
- Two entries:
  1. **Brutl Products** (`brutl_products_screen.dart`) — "Coming Soon" placeholder
  2. **Diet & Workout Plan** (`diet_workout_screen.dart`)

### AI Diet & Workout Plan (`diet_workout_screen.dart`)
**Two-tab interface (Diet | Workout):**

**Diet Plan:**
- Pre-filled from user profile (weight, height, body fat, steps, macros)
- Goal selector: Body Recomp / Weight Loss / Weight Gain / Other
- Budget input with currency (PKR default)
- Number of meals per day
- Duration: 7 Days / 14 Days / 1 Month
- AI generates personalized diet plan
- Download as PDF

**Workout Plan:**
- Experience level: Beginner / Intermediate / Advanced
- Equipment: Full Gym / Home Gym / Bodyweight
- Split selector with preset day names
- Custom day name editing
- AI generates workout plan
- Download as PDF

**PDF Generation:** Uses `pdf` package + `path_provider`

---

## Chat Tab

### `chat_list_screen.dart`
- **Search users:** Firestore query by display name/username, debounced 500ms
- **Send friend requests:** writes to target's `friend_requests` subcollection
- **Friend list:** Live stream from `users/{uid}/friends`, sorted by `addedAt`
- **AI Coach entry:** Fixed tile at top, long-press for rename/delete history
- **Unread badge:** Aggregated from `chats` collection `unreadCount_{uid}` fields

### `chat_room_screen.dart`
- **Message types:** text, meal_share, exercise_share
- **Features:**
  - Reply-to messages (swipe or long-press)
  - Emoji reactions (map: emoji → list of UIDs)
  - Message status: sent → delivered → read
  - Soft delete (for everyone + for me)
  - Expiring messages (configurable TTL)
  - Optimistic send queue (instant UI, then Firestore sync)
  - Typing indicators
  - Image sharing (Firebase Storage upload)

### `friend_requests_screen.dart`
- Accept / Decline pending requests
- Suppression system prevents request flicker after action

### Share Screens
- `share_meal_screen.dart` — Share logged meals to chat/AI
- `share_workout_screen.dart` — Share workout sessions
- `share_pr_screen.dart` — Share personal records

---

## Settings Hub

### `main_settings_screen.dart`

**SettingsActionBoxWidget sections:**

**Account:**
- Account Settings (display name, username, photo)
- Personal Stats (height, weight, age, body fat)
- Credentials (change password)
- Exercise Changes (workout split, days, exercises)
- Blocked Friends (count badge, unblock)

**App:**
- Subscription (placeholder)
- Connected Apps (Spotify integration)
- Contact Support (email `brutlapp@gmail.com`, WhatsApp `+923097719166`)
- Feedback / Suggestion (HTTP POST to webhook)

**Logout:** Red button, clears SharedPreferences + providers, navigates to Login

### Sub-Screens

| Screen | Purpose |
|--------|---------|
| `personal_stats_screen.dart` | View & edit height, weight, age, body fat |
| `account_settings_screen.dart` | Display name, username (30-day change limit), photo upload |
| `credentials_screen.dart` | Change password (requires re-auth) |
| `feedback_screen.dart` | Feedback vs Suggestion toggle, star rating, 30-char minimum, HTTP POST |
| `contact_support_screen.dart` | Email (mailto) + WhatsApp (wa.me) with `canLaunchUrl` validation |
| `blocked_friends_screen.dart` | List blocked users, unblock action |
| `subscription_screen.dart` | Placeholder |
| `connected_apps_screen.dart` | SpotifyTile → connect/disconnect bottom sheet |

### Workout Settings (`workout_settings/`)
- **`exercise_settings_screen.dart`** — Entry hub with 4 options
- **`split_change_screen.dart`** — Replace entire split, wipes exercises, resets program start
- **`edit_days_screen.dart`** — Rename individual days, clear exercises from day
- **`rep_ranges_screen.dart`** — Edit compound (min/max) and isolation (min/max) rep ranges

**Optimistic Updates:** All settings use `BrutlUserProvider.applyOptimistic()` — local state updates immediately, Firestore write happens in background, rollback on failure.

---

## AI Coach / Elite AI Trainer

### Architecture
- **Provider:** `ai_coach_provider.dart`
- **Screen:** `ai_chat_screen.dart` (Elite AI Coach)
- **Also embedded in:** `home_screen.dart` (Ask AI dialog)

### Features
- Persistent chat history stored in Firestore: `users/{uid}/ai_coach/messages/messages/`
- 14-day message retention with automatic pruning
- Local cache in SharedPreferences for offline access
- Paginated loading (20 messages per page) with scroll-up to load older
- Attachments: workout share, meal share, PR share, photo analysis
- Rename chat title (local only)
- Delete entire chat history

### AI Generation Pipeline
1. **Primary:** OpenRouter (`deepseek-v4-flash`) with full conversation context
2. **Fallback (legacy code in home_screen.dart):** Gemini Flash → Grok beta
3. **System prompt:** From `core/theme/constants/ai_coach.dart`

### Message Model
```dart
AiCoachMessage {
  id, role (user/assistant), content,
  timestamp, attachmentType, attachmentData
}
```

---

## Providers (State Management)

| Provider | File | Responsibility |
|----------|------|--------------|
| `BrutlAuthProvider` | `auth_provider.dart` | Email/Google auth, sign out, password reset, country code injection |
| `AuthValidationProvider` | `auth_validation_provider.dart` | Login/signup validation state, password visibility toggles |
| `BrutlUserProvider` | `brutl_user_provider.dart` | Live Firestore user doc, optimistic updates for all profile fields |
| `WorkoutProvider` | `workout_provider.dart` | Workout splits, weeks, program start date, exercise cache versioning |
| `WorkoutNutritionProvider` | `workout_nutrition_provider.dart` | Workout tab bottom nav index, UI strings |
| `StepProvider` | `health_provider.dart` | Pedometer permission, sensor stream, calorie calculation, weight updates |
| `ChatProvider` | `chat_provider.dart` | Friends stream, requests, send/accept/decline, message CRUD, reactions |
| `AiCoachProvider` | `ai_coach_provider.dart` | AI chat messages, OpenRouter generation, local cache, pruning |
| `WaterProvider` | `water_provider.dart` | Daily water intake, goal setting, per-day persistence |

---

## Models

### `BrutlUser` (`user_model.dart`) — Canonical User Document

| Field | Type | Default | Firestore Key |
|-------|------|---------|---------------|
| `uid` | String | — | `uid` |
| `displayName` | String | `''` | `display_name` |
| `username` | String | `''` | `username` |
| `country` | String | `''` | `countryCode` + `country` |
| `gender` | String | `'Other'` | `gender` |
| `age` | int | `0` | `age` |
| `height` | double | `0.0` | `height` |
| `heightUnit` | String | `'cm'` | `height_unit` |
| `weight` | double | `0.0` | `weight` |
| `weightUnit` | String | `'kg'` | `weight_unit` |
| `bodyFatString` | String | `''` | `body_fat_string` |
| `bodyFatAverage` | double | `0.0` | `body_fat_average` |
| `dailySteps` | int | `10000` | `step_goal` |
| `bodyGoal` | String | `'Maintenance'` | `body_goal` |
| `workoutSplitTemplate` | String | `'Push, Pull, Legs, Repeat'` | `workout_split_template` |
| `customSplitDays` | List<String> | `[]` | `custom_split_days` |
| `compoundRepMin/Max` | int | `4` / `8` | `compound_rep_min/max` |
| `isolationRepMin/Max` | int | `8` / `12` | `isolation_rep_min/max` |
| `targetCalories` | int | `2000` | `target_calories` |
| `maintenanceCalories` | int | `2000` | `maintenance_calories` |
| `targetProtein` | int | `150` | `target_protein` |
| `targetCarbs` | int | `200` | `target_carbs` |
| `targetFats` | int | `60` | `target_fats` |
| `bodyMeasurements` | List<Map> | `[]` | `body_measurements` |
| `isProfileComplete` | bool | `false` | `is_profile_complete` |
| `photoUrl` | String | `''` | `photo_url` |
| `usernameChangedAt` | DateTime? | `null` | `username_changed_at` |
| `createdAt` | DateTime? | `null` | `created_at` |

### `ExerciseModel` (`brutl_models.dart`)
```dart
ExerciseModel {
  id, name, sets, reps, weight, categoryType,
  weightUnit = 'Kg', isSynced = false, splitName = ''
}
```
- `repValues`: Parses numeric values from rep strings via regex
- `averageReps`: Computed from parsed rep values
- `toJson()` / `fromJson()`: Full serialization with weight parsing fallbacks

### `MessageModel` (`chat_models.dart`)
```dart
MessageModel {
  id, senderId, timestamp, expiresAt, type ('text'|'meal_share'|'exercise_share'),
  payload, status, readAt,
  replyToId, replyToSenderId, replyToPreview,
  reactions, isDeleted, deletedFor
}
```

### `FriendModel` (`chat_models.dart`)
```dart
FriendModel {
  uid, nickname, displayName, username, photoUrl, addedAt,
  isPinned, isMuted, isBlocked
}
```
- `resolvedName`: nickname → displayName → @username

### `BodyMeasurement` (`body_measurement_model.dart`)
- Canonical storage in **centimeters**
- Display unit per-measurement: `cm` or `inch`
- Defaults: Chest 40", Thigh 45", Arms 16", Waist 38"

---

## Services

### `FirebaseBootstrap` (`firebase_bootstrap.dart`)
- Initializes Firebase Core
- Activates App Check (Android debug provider)
- Debug token embedded for development

### `StepService` (`step_service.dart`) — Singleton
- Wraps `Pedometer.stepCountStream`
- **Baseline system:** Stores initial hardware counter at day start
- Computes `dailySteps = rawHardware - baseline`
- Handles midnight rollover, phone reboot detection
- Hourly save to history
- 28-day history retention in SharedPreferences

### `StepSensorService` (`step_sensor_service.dart`)
- Lower-level sensor math companion to `StepService`
- `todaysStepsStream`: deduplicated broadcast stream
- `refreshFromSensor()`: force re-read on app resume

### `LocalStorageService` (`local_storage_service.dart`)
- Hive `steps_history` box
- 28-day retention with auto-pruning
- Seeded placeholder data for new users
- Daily average calculation

### `BackgroundService` (`background_service.dart`)
- Workmanager `callbackDispatcher` (top-level function, isolate-safe)
- Task: `brutl_step_sync` runs every ~15 minutes
- Reads pedometer, handles midnight rollover, persists baselines
- No UI/Provider references (pure function design)

### `DatabaseService` (`database_service.dart`)
- **Local-first architecture:**
  - Exercises saved to Hive `exercises` box FIRST (key=exercise.id, value=JSON)
  - Fire-and-forget Firestore sync via `unawaited`
  - Mark `isSynced: true` only after Firestore confirms
- Methods: `saveExercise`, `syncExercise`, `syncPendingExercises`, `getExercisesForSplit`, `fetchUserProfile`, `syncExercisesFromFirestore`

### `GeoService` (`geo_service.dart`)
- Detects user country via `ipinfo.io` API (token from `secrets.dart`)
- Tier-1 country detection (US, GB, CA, AU, DE, FR)
- Pakistan detection for shop gating
- Caches result in SharedPreferences + Firestore

### `NutritionService` (`nutrition_service.dart`)
- Singleton for meal/calorie tracking
- `NutritionData` stream broadcast
- Methods: `loadTodayNutrition()`, `saveGoals()`, `logMeal()`, `removeMeal()`
- Persists to SharedPreferences with date-keyed entries

### `CalorieHistoryService` (`calorie_history_service.dart`)
- Aggregates 7-day macro history
- Date-stamped snapshots: calories, carbs, protein, fat, water

### `AiMealService` (`ai_meal_service.dart`)
- **Primary:** Google Gemini 1.5 Flash (image → JSON macros)
- **Fallback:** DeepSeek V4 via OpenRouter
- Image compression: resize to 800px, JPEG quality 80
- Returns: `{kcal, carbs, protein, fat}`

### `AiDietPlanService` (`ai_diet_plan_service.dart`)
- Generates structured diet plans via AI
- PDF output via `pdf` package

---

## Widgets (Reusable UI)

| Widget | File | Purpose |
|--------|------|---------|
| `BiometricCard` | `biometric_card.dart` | Steps & Calories cards with circular progress |
| `WaterCard` | `water_card.dart` | Compact water progress bar, opens bottom sheet |
| `MacroDashboardCard` | `macro_dashboard_card.dart` | Circular ring showing carbs/protein/fats |
| `WorkoutCardWidget` | `workout_card_widget.dart` | Individual workout day card |
| `ExerciseCardWidget` | `exercise_card_widget.dart` | Exercise display with sets/reps/weight |
| `ExerciseEditorSheet` | `exercise_editor_sheet.dart` | Bottom sheet to add/edit exercises |
| `MealLoggerSheet` | `meal_logger_sheet.dart` | Bottom sheet for meal logging (photo + text) |
| `AskAiDialog` | `ask_ai_dialog.dart` | Floating quick-action AI dialog |
| `OtpVerificationSheet` | `otp_verification_sheet.dart` | OTP input with auto-focus |
| `PasswordInputField` | `password_input_field.dart` | Reusable password field with toggle |
| `ExerciseHighlightCard` | `exercise_highlight_card.dart` | Last workout highlight on home |
| `WorkoutDayCard` | `workout_day_card.dart` | Day card for split display |

---

## Data Layer (Firestore + Local)

### Local Storage Strategy

| Data | Storage | Key/Box |
|------|---------|---------|
| Exercises | Hive | `exercises` (Box<String>) |
| Step history | Hive | `steps_history` (Box<int>) |
| User model | SharedPreferences | `brutl_user_model` |
| Workout split | SharedPreferences | `brutl_workout_split` |
| Program start | SharedPreferences | `brutl_program_start_date` |
| Step baseline | SharedPreferences | `baseline_steps`, `today_steps`, `last_reset_date` |
| Step history (SP) | SharedPreferences | `step_history` |
| Nutrition today | SharedPreferences | `nutrition_YYYY-MM-DD` |
| Water intake | SharedPreferences | `water_intake_ml_YYYY-MM-DD` |
| Water goal | SharedPreferences | `water_goal_liters` |
| AI chat cache | SharedPreferences | `ai_coach_messages_{uid}` |
| AI chat title | SharedPreferences | `ai_coach_title_{uid}` |
| Country code | SharedPreferences | `country_code_{uid}` |
| Goals | SharedPreferences | `calorie_goal`, `carbs_goal`, `protein_goal`, `fats_goal` |

### Sync Strategy
- **Write:** Local first → Firestore fire-and-forget
- **Read:** Firestore stream with SharedPreferences fallback
- **Offline:** Full exercise data available from Hive
- **Steps:** Never written to Firestore (cost saving, local only)

---

## Firebase Collections Schema

### `users/{uid}` — User Profile Document
```json
{
  "uid": "...",
  "email": "...",
  "display_name": "...",
  "username": "...",
  "username_lower": "...",
  "photo_url": "...",
  "countryCode": "PK",
  "country": "Pakistan",
  "gender": "Male",
  "age": 25,
  "height": 175.0,
  "height_unit": "cm",
  "weight": 70.0,
  "weight_unit": "kg",
  "body_fat_string": "11% to 15%",
  "body_fat_average": 13.0,
  "step_goal": 10000,
  "body_goal": "Weight Loss",
  "workout_split_template": "Push/Pull/Legs",
  "custom_split_days": ["Chest & Triceps", "Back & Biceps", "Legs & Shoulders", ...],
  "workout_master_template": ["Chest & Triceps", ...],
  "compound_rep_min": 4,
  "compound_rep_max": 8,
  "isolation_rep_min": 8,
  "isolation_rep_max": 12,
  "target_calories": 2000,
  "maintenance_calories": 2500,
  "target_protein": 150,
  "target_carbs": 200,
  "target_fats": 60,
  "body_measurements": [{"id": "...", "name": "Chest", "value_cm": 101.6, "display_unit": "cm"}],
  "is_profile_complete": true,
  "program_start_date": Timestamp,
  "created_at": Timestamp,
  "last_sign_in_at": Timestamp,
  "currentSteps": 5000
}
```

### `users/{uid}/friends/{friendUid}` — Friend Document
```json
{
  "uid": "...",
  "nickname": "",
  "displayName": "...",
  "username": "...",
  "photoUrl": "...",
  "addedAt": Timestamp,
  "isPinned": false,
  "isMuted": false,
  "isBlocked": false
}
```

### `users/{uid}/friend_requests/{senderUid}` — Friend Request
```json
{
  "senderUid": "...",
  "senderDisplayName": "...",
  "senderUsername": "...",
  "senderPhotoUrl": "...",
  "status": "pending",
  "timestamp": Timestamp
}
```

### `users/{uid}/workouts/{exerciseId}` — Exercise Document
```json
{
  "id": "...",
  "name": "Bench Press",
  "sets": 4,
  "reps": "8, 8, 7, 6",
  "weight": "80",
  "categoryType": "compound",
  "weightUnit": "Kg",
  "isSynced": true,
  "splitName": "Chest & Triceps",
  "updatedAt": Timestamp
}
```

### `users/{uid}/weeks/{weekId}/days/{dayId}` — Workout Day
```json
{
  "exercises": [...],
  "updatedAt": Timestamp
}
```

### `chats/{chatId}` — Chat Room Document
```json
{
  "participants": ["uidA", "uidB"],
  "unreadCount_uidA": 3,
  "unreadCount_uidB": 0,
  "lastMessage": {...},
  "lastMessageAt": Timestamp
}
```

### `chats/{chatId}/messages/{messageId}` — Message Document
```json
{
  "id": "...",
  "senderId": "...",
  "timestamp": Timestamp,
  "expiresAt": Timestamp,
  "type": "text",
  "payload": {"text": "Hello!"},
  "status": "read",
  "readAt": Timestamp,
  "replyToId": "...",
  "reactions": {"👍": ["uid1", "uid2"]},
  "isDeleted": false,
  "deletedFor": []
}
```

### `users/{uid}/ai_coach/messages/{messageId}` — AI Coach Message
```json
{
  "id": "...",
  "role": "user|assistant",
  "content": "...",
  "timestamp": FieldValue.serverTimestamp(),
  "attachmentType": "workout_share",
  "attachmentData": {...}
}
```

### `users/{uid}/ai_coach/summary` — AI Summary
```json
{
  "summary": "User is focusing on chest strength...",
  "updatedAt": Timestamp
}
```

---

## External Integrations

### AI Providers
| Provider | Endpoint | Model | Usage |
|----------|----------|-------|-------|
| OpenRouter | `openrouter.ai/api/v1/chat/completions` | `deepseek-v4-flash` | AI Coach primary |
| Google Gemini | `generativelanguage.googleapis.com` | `gemini-1.5-flash-latest` | Meal photo analysis, AI Coach fallback |
| xAI Grok | `api.x.ai/v1/chat/completions` | `grok-beta` | AI Coach fallback (legacy) |

### IP Geolocation
- **Service:** ipinfo.io
- **Purpose:** Country detection for shop gating & analytics
- **Token:** Stored in `lib/config/secrets.dart`

### Communication
- **Email:** `mailto:brutlapp@gmail.com` (Contact Support)
- **WhatsApp:** `https://wa.me/923097719166` (Contact Support)

### OAuth
- **Google Sign-In:** `google_sign_in` package, Firebase Auth credential exchange

---

## Build & Configuration

### `pubspec.yaml`
- Version: `1.0.0+1`
- Dart SDK: `^3.11.0`

### Assets
```yaml
assets:
  - assets/Images/Male_BodyFat.png
  - assets/Images/Female_BodyFat.png
  - assets/Images/google_logo.jpg
  - assets/Images/logo.png
  - assets/Images/transparent.png
```

### Fonts
```yaml
fonts:
  - family: Myfont
    fonts:
      - asset: lib/Screens/Myfont.ttf
```

### Launcher Icons
- Android & iOS enabled
- Source: `assets/Images/logo.png`
- Adaptive icon background: `#0A0A0A`

### Native Splash
- Color: `#0A0A0A`
- Image: `assets/Images/transparent.png`
- Android 12+ specific config included

---

## Key Architectural Patterns

1. **Optimistic UI:** All profile updates mutate local state immediately, then persist to Firestore. Rollback on failure.
2. **Local-First:** Exercises and step data live in Hive/SharedPreferences first. Firestore is secondary.
3. **Provider Pattern:** All state lives in ChangeNotifierProviders registered at app root.
4. **Stream-Based:** Firestore snapshots drive real-time UI updates (friends, messages, user doc).
5. **Service Singletons:** StepService, NutritionService are singletons with broadcast streams.
6. **Geo-Gating:** Shop features vary by detected country (Pakistan gets Brutl Products).
7. **Two-Phase Warmup:** Disk I/O and network I/O run in parallel phases to minimize startup time.
8. **Day-Rollover Safety:** Steps and water reset automatically when the date changes, even while backgrounded.

---

*Document generated from full codebase analysis.*
