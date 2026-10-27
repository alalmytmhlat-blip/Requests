# Requests — تطبيق طلبات الأصناف

Flutter Android application for recording shortages, managing a shared item catalog, reviewing requests, and configuring business identity.

## Current scaffold
- Arabic RTL UI
- Local SQLite item catalog and requests
- Item classification is captured when creating a new item, not on the shortage request form
- Request status review: جديد، قيد التجهيز، تم توفيره، غير متوفر
- Editable business settings: name, address, two phone numbers, user/worker display name
- GitHub Actions workflow builds a release APK and uploads it as an artifact

## Cloud sync and authentication
Firebase packages are declared, but Firebase project configuration, worker/admin authentication, Firestore security rules, and actual online synchronization are not yet implemented. Do not treat this scaffold as production-ready or deploy it with real staff data until these are completed and tested.

## Build
The GitHub Actions workflow runs on pushes to `main` and manual dispatch. Open Actions → Build Android APK → latest successful run → download `requests-android-apk`.

Flutter release build documentation: https://docs.flutter.dev/deployment/android
