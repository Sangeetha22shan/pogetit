# PoGetIt – GPS Quest Validation & Step Counting Prototype

## Project Overview

PoGetIt is a Flutter-based mobile application that allows users to participate in location-based and physical activity quests, track their progress, validate quest requirements, and earn experience points (XP).

The application integrates GPS location tracking, Android Health Connect, Firebase Authentication, Cloud Firestore, and Firebase Cloud Functions to provide a quest completion and reward system with server-side validation.

## Features

- Anonymous authentication using Firebase Authentication.
- Dynamic quest retrieval from Cloud Firestore.
- Available, Ongoing, and Completed quest categories.
- Quest acceptance and progress tracking.
- GPS-based geofence validation.
- Real-time GPS distance tracking.
- Step counting using Android Health Connect.
- Server-side quest validation using Firebase Cloud Functions.
- Automatic XP rewards upon successful quest completion.
- Duplicate reward prevention using Firestore transactions.
- Persistent quest progress and user statistics.
- Permission handling and error feedback.

## Technology Stack

| Technology | Purpose |
|---|---|
| Flutter | Mobile application development |
| Dart | Programming language |
| MVVM | Application architecture |
| ChangeNotifier | State management |
| RepositoryProvider | Dependency injection |
| Firebase Authentication | Anonymous user authentication |
| Cloud Firestore | Quest and user data storage |
| Firebase Cloud Functions | Server-side quest validation |
| Geolocator | GPS tracking and distance calculation |
| Health Connect | Android step data integration |
| Firebase Emulator Suite | Backend integration testing |

## Application Architecture

The application follows the Model-View-ViewModel (MVVM) architecture with the Repository pattern.

```text
View (Flutter UI)
       |
       v
ViewModel (ChangeNotifier)
       |
       v
Repository / Service Layer
       |
       v
Firebase / GPS / Health Connect
```

### Architecture Responsibilities

- **Model:** Represents quest definitions, user quest progress, and validation results.
- **View:** Displays quest lists, tracking progress, user statistics, and validation feedback.
- **ViewModel:** Manages application state, quest operations, tracking, and validation.
- **Repository:** Handles communication with Firebase services.
- **Service:** Handles device location, permissions, and Health Connect integration.

## Project Structure

```text
pogetit/
├── android/
├── lib/
│   ├── data/
│   │   ├── repositories/
│   │   └── services/
│   │       ├── location_service.dart
│   │       └── health_service.dart
│   ├── features/
│   │   └── quests/
│   │       ├── model/
│   │       ├── view/
│   │       └── viewmodel/
│   ├── firebase_options.dart
│   └── main.dart
├── functions/
│   ├── index.js
│   ├── package.json
│   └── test/
├── test/
├── firebase.json
├── firestore.rules
├── pubspec.yaml
└── README.md
```

## Supported Quest Types

### 1. Café Visit Quest

The user must visit a predefined café location and

## Usage and Ownership

This project is submitted exclusively for technical evaluation as part of a freelance screening process.

The source code is not licensed for commercial use or production deployment. Any commercial usage or transfer of intellectual property requires a separate written agreement with the developer.