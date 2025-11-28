# Gemini Project Analysis: In-Sign

This document provides a comprehensive overview of the "In-Sign" project, a digital contract management and electronic signature platform. It is intended to be used as a quick-start guide and reference for developers.

## Project Overview

In-Sign is a full-stack application consisting of a Flutter-based mobile/web frontend and a NestJS-based backend.

### Frontend (Flutter)

The frontend is a cross-platform application built with Flutter. It allows users to manage digital contracts, sign documents electronically, and interact with the platform's features.

*   **State Management:** `flutter_bloc` is used for state management, following the BLoC pattern.
*   **Navigation:** `go_router` is used for routing and navigation.
*   **Authentication:** The app supports authentication via Google and Kakao.
*   **Core Features:**
    *   Digital contract viewing and signing.
    *   PDF generation and printing.
    *   File picking and management.
    *   Push notifications via Firebase.

### Backend (NestJS)

The backend is a robust API server built with NestJS. It provides the necessary APIs for the frontend, manages the database, and handles business logic.

*   **Framework:** Built with NestJS, a progressive Node.js framework.
*   **Database:** Uses TypeORM to interact with a MySQL database.
*   **Authentication:** Implements session-based authentication using Passport.
*   **API Documentation:** Provides automated API documentation via Swagger.
*   **Admin Portal:** Includes an admin portal for managing users and other aspects of the application.

## Building and Running

### Backend (NestJS)

1.  **Install Dependencies:**
    ```bash
    cd nestjs_app
    npm install
    ```

2.  **Configure Environment:**
    Create a `.env` file in the `nestjs_app` directory with the following variables:
    ```
    PORT=8081
    DB_HOST=localhost
    DB_PORT=3306
    DB_USERNAME=root
    DB_PASSWORD=secret
    DB_NAME=insign
    SESSION_SECRET=change-me
    ```

3.  **Run Development Server:**
    ```bash
    npm run start:dev
    ```
    The server will be running at `http://localhost:8081`. The default admin credentials are `admin` / `admin1234`.

### Frontend (Flutter)

1.  **Install Dependencies:**
    ```bash
    cd insign_flutter
    flutter pub get
    ```

2.  **Run the App:**
    ```bash
    flutter run
    ```
    This will run the app on a connected device or simulator. To run on a specific platform, use the `-d` flag (e.g., `flutter run -d chrome`).

## Development Conventions

*   **Backend:**
    *   The backend follows the standard NestJS project structure.
    *   Use the provided `npm` scripts for common tasks (e.g., `start:dev`, `build`, `test`).
    *   API endpoints should be documented with Swagger DTOs.
*   **Frontend:**
    *   The frontend uses the BLoC pattern for state management.
    *   Code should adhere to the lints defined in `analysis_options.yaml`.
    *   Use `go_router` for all navigation logic.
    *   Follow the existing project structure for new features.
