# Firebase Setup Instructions

This app uses Firebase Authentication for phone number login. Follow these steps to set up Firebase:

## Method 1: Using FlutterFire CLI (Recommended)

1. Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

2. Run the configuration command:
```bash
flutterfire configure
```

3. This will automatically generate `lib/firebase_options.dart` with your Firebase project configuration.

## Method 2: Manual Configuration

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select an existing project
3. Follow the setup wizard

### 2. Get Your Firebase Configuration

1. In Firebase Console, go to **Project Settings** (gear icon)
2. Scroll down to "Your apps" section
3. For each platform (Android, iOS, Web), you'll find the configuration values

### 3. Update firebase_options.dart

Open `lib/firebase_options.dart` and replace the placeholder values with your actual Firebase configuration:

- `apiKey`: Found in Firebase Console > Project Settings
- `appId`: Found in Firebase Console > Project Settings
- `messagingSenderId`: Found in Firebase Console > Project Settings
- `projectId`: Your Firebase project ID
- `storageBucket`: Usually `YOUR_PROJECT_ID.appspot.com`
- `authDomain`: Usually `YOUR_PROJECT_ID.firebaseapp.com` (for web)
- `iosBundleId`: `in.techgigs.goodiesworld` (already set)

## 3. Enable Phone Authentication

1. In Firebase Console, go to **Authentication** > **Sign-in method**
2. Enable **Phone** as a sign-in provider
3. Save the changes

## 3. Android Setup

1. In Firebase Console, click the Android icon to add an Android app
2. Register your app with package name: `in.techgigs.goodiesworld`
3. Download the `google-services.json` file
4. Place it in `android/app/` directory

5. Update `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

6. Update `android/app/build.gradle`:
```gradle
plugins {
    id "com.google.gms.google-services"
}
```

## 4. iOS Setup

1. In Firebase Console, click the iOS icon to add an iOS app
2. Register your app with bundle ID: `in.techgigs.goodiesworld`
3. Download the `GoogleService-Info.plist` file
4. Place it in `ios/Runner/` directory using Xcode

## 5. Install Dependencies

Run the following command in your project root:
```bash
flutter pub get
```

## 6. Test the App

1. Run the app: `flutter run`
2. The flow will be: Splash Screen → Phone Login → OTP Verification → Homepage

## Notes

- For testing, you can use test phone numbers in Firebase Console under Authentication > Sign-in method > Phone > Phone numbers for testing
- Make sure your phone number includes country code (e.g., +1234567890)
- The app will automatically format phone numbers with a '+' prefix if not provided

