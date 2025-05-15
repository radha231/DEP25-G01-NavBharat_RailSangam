# App Setup and Installation Guide

## System Requirements
- Operating System: Windows 10/11 or macOS
- RAM: Minimum 8 GB (16 GB recommended)
- Internet connection

## Installation Steps

### 1. Install Java JDK (Version 17.0.12)
- Download JDK 17.0.12 from the official Oracle website: [Oracle JDK 17 Downloads](https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html)
- Install the JDK
- Recommended installation path: `C:\Program Files\Java\jdk-17` (Windows) or appropriate location on macOS

### 2. Install Android Studio
- Download and install Android Studio (preferably the Ladybug Feature Drop version): [Android Studio](https://developer.android.com/studio)
- During installation, ensure to include:
  - Android SDK
  - Android SDK Platform-Tools
  - Android Emulator

### 3. Set Java SDK Path in Android Studio
- Open the file `android/gradle.properties` and add:
  ```
  org.gradle.java.home=C:\\Program Files\\Java\\jdk-17
  ```
  (Adjust the path according to your JDK installation directory)

### 4. Install Node.js and npm
- Download and install Node.js from: [Node.js](https://nodejs.org)
- Verify installation by running:
  ```
  node -v
  npm -v
  ```

### 5. Install Firebase CLI
- Run the following command in your terminal:
  ```
  npm install -g firebase-tools
  ```
- Log in to Firebase:
  ```
  firebase login
  ```
- Make sure the email you use is added to the allowed users in your Firebase project

### 6. Set Up FlutterFire CLI
- Install Dart SDK (if not already installed): [Dart SDK](https://dart.dev/get-dart)
- Run:
  ```
  dart pub global activate flutterfire_cli
  ```
- (Optional) Configure FlutterFire:
  ```
  flutterfire configure --project=classico-dc2a9
  ```
### 7. Clone the Repository
 - Note: This is a private repository. You must be added as a contributor to access it.
 - If you already have access:
   ```bash
   git clone https://github.com/radha231/DEP25-G01-NavBharat_RailSangam.git
   ```
  - If you already have the code then just open it in Android Studio 
## Running the App

### Run in Android Studio
- Open the project in Android Studio
- Run using an emulator or connected Android device
- On first launch, the app will request permissions for:
  - Notifications
  - Location tracking
- Grant these permissions to enable full functionality

### Run on Physical Device
- Enable USB debugging on your Android device:
  - Go to Settings > About Phone
  - Tap "Build Number" 7 times to enable Developer Options
  - Go back to Settings > Developer Options > Enable USB debugging
- Connect your device via USB
- Select your device from the device dropdown in Android Studio
- Click the "Run" button or press Shift+F10

---

You're all set! The app should now run and interact with Firebase as expected.
