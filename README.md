# Local Storage: Connect the Pieces

## Project Overview
This is a Flutter application that uses SQLite to store and manage folders and cards. It builds on the previous assignment by allowing cards to be organized into folders.

## Features
- Create and manage folders and cards.
- Edit card information.
- Delete cards and folders.
- Save data locally using SQLite.
- Preserve data after restarting the application.
- Validate user input and prevent duplicate folder names.

## Testing Results

- **T1 – Database Migration:** Passed. Previous guest information was preserved.
- **T2 – Folders and Cards:** Passed. Folders and cards were created successfully.
- **T3 – Editing Cards:** Passed. Cards could be edited, saved, and cancelled without unwanted changes.
- **T4 – Data Persistence:** Passed. Folders and cards remained available after restarting the application.
- **T5 – Deleting Cards and Folders:** Passed. Cancelled deletions preserved data, and confirmed deletions worked correctly.
- **T6 – Input Validation:** Passed. Invalid inputs and duplicate folder names were rejected, and cards without images displayed a fallback.

## How to Run
1. Open the project in Android Studio or VS Code.
2. Run `flutter pub get`.
3. Connect an Android device or start an emulator.
4. Run `flutter run`.

## Project Structure
- `lib/` – Application source code.
- `evidence/` – Required screenshots and analysis output.
- `README.md` – Project information and test results.

## Conclusion
All six test cases were completed successfully. The application supports local data storage, folder and card management, data persistence, and input validation.