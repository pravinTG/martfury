# Environment Setup Guide

## Step 1: Create Environment Files

Create two files in the root directory:

### `.env.dev` (Development)
```env
# Development Environment Configuration
BASE_URL=https://goodiesworld.techgigs.in
CONSUMER_KEY=
CONSUMER_SECRET=
```

### `.env.prod` (Production)
```env
# Production Environment Configuration
BASE_URL=https://goodiesworld.techgigs.in
CONSUMER_KEY=ck_788d67b8f28f92f5a1a1bc7a6e9adf5a62c7f4fd
CONSUMER_SECRET=cs_c1dd92d3ab6cf683db2d5726e09ca5b261e6b972
```

## Step 2: Run the App

### Development Mode (default)
```bash
flutter run
```
This will load `.env.dev`

### Production Mode
```bash
flutter run --dart-define=APP_ENV=prod
```
This will load `.env.prod`

## Step 3: Build for Release

### Development Build
```bash
flutter build apk --dart-define=APP_ENV=dev
```

### Production Build
```bash
flutter build apk --dart-define=APP_ENV=prod
```

## Important Notes

- `.env.dev` and `.env.prod` are in `.gitignore` (secrets are safe)
- Example files (`env.dev.example` and `env.prod.example`) are provided as templates
- Copy the example files and rename them to `.env.dev` and `.env.prod`
- Fill in your development keys in `.env.dev` if needed

