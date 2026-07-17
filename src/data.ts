import { PackageDetail, FolderResponsibility } from "./types";

export const packagesData: PackageDetail[] = [
  {
    name: "go_router",
    version: "^13.2.0",
    purpose: "Declarative routing & deep-linking engine",
    whyUsed: "GoRouter is standard for Flutter production apps. It allows us to define paths as strings (/admin/dashboard, /employee/attendance), handles complex redirect checks (e.g. redirecting unauthenticated users to /login), supports nested tabs (StatefulShellRoute), and handles parameter parsing elegantly."
  },
  {
    name: "flutter_riverpod",
    version: "^2.4.9",
    purpose: "Reactive State Management & Compile-Safe Dependency Injection",
    whyUsed: "Riverpod is the state-of-the-art solution for Flutter. Unlike Provider, it is completely independent of the Widget tree, meaning we can inject repository dependencies, services, or loggers without carrying a BuildContext. It catches architectural reference errors at compile time instead of runtime."
  },
  {
    name: "firebase_core",
    version: "^2.27.0",
    purpose: "Firebase initialization engine",
    whyUsed: "Required to initialize all client-side Firebase products (Firestore, Auth, Storage, Messaging) under a unified secure context."
  },
  {
    name: "firebase_auth",
    version: "^4.17.8",
    purpose: "Corporate secure user authentication",
    whyUsed: "Used to manage employee sessions, token refreshes, password resets, and credential verification. Native mobile state management automatically restores sessions across app reboots."
  },
  {
    name: "cloud_firestore",
    version: "^4.15.8",
    purpose: "Private corporate document-based database",
    whyUsed: "Stores user profiles, logs, geofences, and records. It is configured with local caching (offline support) so field workers can submit logs and track records even in dead-zones (no network coverage), which will automatically sync once a connection is re-established."
  },
  {
    name: "firebase_storage",
    version: "^11.6.9",
    purpose: "Secure binary cloud storage (attachments & images)",
    whyUsed: "Required for field service workflows (e.g., uploading completion photos, customer signatures, receipt scans, or equipment damage reports)."
  },
  {
    name: "firebase_messaging",
    version: "^14.7.19",
    purpose: "Real-time Push Notifications & FCM",
    whyUsed: "Enables instant push communication from Admin. Since maximum employees is 6, notifications alert workers to newly assigned field schedules, coordinate geofencing triggers, or send system broadcasts instantly."
  },
  {
    name: "google_maps_flutter",
    version: "^2.5.3",
    purpose: "Interactive Map Visualization & Geofencing",
    whyUsed: "Used for real-time customer address pinning, routing optimization, and checking in-bounds coordinates for attendance verification based on designated client coordinates."
  },
  {
    name: "intl",
    version: "^0.19.0",
    purpose: "Localization & DateTime formatting",
    whyUsed: "Critical for corporate audit compliance—ensures time-clocking, report scheduling, and calendar dates are translated perfectly across local time zones."
  },
  {
    name: "dio",
    version: "^5.4.0",
    purpose: "High-performance HTTP client",
    whyUsed: "Used for raw external REST requests (such as fetching geocoding coordinates, interacting with custom backend API triggers, or fetching third-party telemetry data)."
  }
];

export const foldersData: FolderResponsibility[] = [
  {
    path: "lib/core/theme/",
    name: "Core Theme",
    purpose: "Centralized corporate styling & visual guidelines",
    layer: "core",
    details: [
      "color_schemes.dart: Houses custom Material 3 Light/Dark ColorScheme objects featuring Copper Brown and Warm Brown.",
      "app_theme.dart: Governs typography pairing (SpaceGrotesk for display, JetBrainsMono for monospace telemetry) and configures the 14px border radius on elevated buttons, text fields, and custom cards."
    ]
  },
  {
    path: "lib/core/routing/",
    name: "Core Routing",
    purpose: "State-aware secure application routing",
    layer: "core",
    details: [
      "app_router.dart: Configures GoRouter. It actively watches the authProvider so that any change in user state (login, logout, deactivation) instantly evaluates and routes the app to the safe destination."
    ]
  },
  {
    path: "lib/core/error/",
    name: "Core Error Abstractions",
    purpose: "Systematic failure modeling",
    layer: "core",
    details: [
      "failures.dart: Declares ServerFailure, AuthFailure, CacheFailure, and LocationFailure. Ensures the app handles errors as returning values instead of crashing the process."
    ]
  },
  {
    path: "lib/core/widgets/",
    name: "Core Widgets",
    purpose: "Highly reusable visual building blocks",
    layer: "core",
    details: [
      "custom_button.dart: An elevated brand-aligned Material 3 Copper Brown button supporting custom loaders.",
      "custom_card.dart: Custom card with 14px rounded corners and smooth shadows matching branding rules.",
      "loading_indicator.dart: Progress spinner designed strictly within corporate style specs."
    ]
  },
  {
    path: "lib/features/auth/domain/models/",
    name: "Auth Domain Models",
    purpose: "Immutable corporate structures & domain entities",
    layer: "domain",
    details: [
      "user_model.dart: Models corporate employees (Admin vs Employee). Implements role helpers (.isAdmin, .isEmployee) and immutable copyWith methods."
    ]
  },
  {
    path: "lib/features/auth/domain/repositories/",
    name: "Auth Domain Contracts",
    purpose: "Pure interface definitions decoupled from SDKs",
    layer: "domain",
    details: [
      "auth_repository.dart: The repository contract. It contains no Firebase code, ensuring that the presentation layer only talks to pure, testable abstractions."
    ]
  },
  {
    path: "lib/features/auth/data/sources/",
    name: "Auth Remote Datasources",
    purpose: "Low-level SDK interaction boundary",
    layer: "data",
    details: [
      "auth_remote_source.dart: Encapsulates direct interaction with FirebaseAuth and Cloud Firestore collections. Bubbles up exceptions directly."
    ]
  },
  {
    path: "lib/features/auth/data/repositories/",
    name: "Auth Repository Implementations",
    purpose: "SDK error interception & domain mapping",
    layer: "data",
    details: [
      "auth_repository_impl.dart: Implements AuthRepository. It wraps data sources, traps FirebaseAuthExceptions, and converts them to typed AuthFailures for the presentation layer to display."
    ]
  },
  {
    path: "lib/features/auth/presentation/providers/",
    name: "Auth State Providers",
    purpose: "Reactive controllers & Dependency Injection",
    layer: "presentation",
    details: [
      "auth_provider.dart: Exposes authRemoteSourceProvider, authRepositoryProvider, the active session stream authProvider, and the interactive authControllerProvider."
    ]
  }
];

export const bestPracticesGuides = [
  {
    title: "1. Declarative Role-Based Access Control (RBAC)",
    description: "Instead of hardcoding navigation restrictions on every single screen, navigation security is enforced globally inside lib/core/routing/app_router.dart. GoRouter watches the Riverpod authProvider stream. If an authenticated user's role is Employee, but they try to visit /admin/dashboard, GoRouter instantly intercepts and reverts them back to /employee/dashboard. This ensures that unauthorized routes are completely unreachable."
  },
  {
    title: "2. SDK Decoupling (Clean Architecture Boundaries)",
    description: "To prevent vendor lock-in and make the app highly unit-testable, we never import firebase_auth or cloud_firestore in our widgets. Widgets only interact with Riverpod Providers, which read domain contracts (AuthRepository). If the company decides to migrate from Firebase to an on-premise PostgreSQL or a custom REST API in the future, only the Data layer (AuthRemoteSource and AuthRepositoryImpl) changes; the entire UI and Domain logic remains completely untouched."
  },
  {
    title: "3. Robust Error Management with Failures",
    description: "In production, raw database exceptions (e.g. FirebaseException: [cloud_firestore/permission-denied]) look unprofessional and leak architecture secrets. We intercept all database exceptions inside the Repository Implementation, mapping them into standard corporate Failure models (failures.dart) containing clear, human-readable instructions. The UI then safely handles these Failures as returned parameters."
  },
  {
    title: "4. Resource-Saving Architecture",
    description: "Since the app is limited to 7 active users (1 Admin + 6 Employees), we keep the client-side execution lightweight and fast. Firestore's offline persistence is enabled by default on Flutter. We avoid heavy polling or unnecessary active listeners; state is updated reactively, saving cellular battery and network bandwidth for field workers."
  }
];

export const scalabilityPlan = [
  {
    phase: "Phase 1: Secure Login Implementation",
    objective: "Implement corporate user authentication form matching branding colors.",
    steps: [
      "Create lib/features/auth/presentation/screens/login_screen.dart using CustomButton and InputDecorationTheme styling.",
      "Integrate authControllerProvider.notifier.login(email, password) in the login button callback.",
      "Handle display of Failures using clean standard Material 3 snackbars."
    ]
  },
  {
    phase: "Phase 2: Attendance Tracking & Geofencing",
    objective: "Add clock-in and clock-out features restricted by corporate HQ GPS coordinates.",
    steps: [
      "Create lib/features/attendance/ folder mirroring the auth clean architecture folder structure.",
      "Define AttendanceModel, AttendanceRepository interface, and AttendanceRemoteSource using cloud_firestore.",
      "Implement geofencing verification: compare current GPS coordinates against HQ coordinates with Google Maps geolocator before writing the clock-in document."
    ]
  },
  {
    phase: "Phase 3: Real-Time Field Job Dispatch",
    objective: "Let Admin assign service coordinates and send push messages to employees.",
    steps: [
      "Create lib/features/jobs/ folder containing JobModel (job location, service checklist, status).",
      "Configure Firebase Cloud Messaging (FCM) token synchronization inside lib/core/services/notification_service.dart.",
      "Implement push handler: when Admin creates a Firestore job document, a secure Cloud Function triggers FCM and notifies the assigned employee instantly."
    ]
  }
];
