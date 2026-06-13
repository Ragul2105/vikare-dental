# Dental Clinic Frontend

Flutter Android app for clinic staff and doctors.

## Stack

- Flutter
- Riverpod
- Dio
- GoRouter
- Hive
- flutter_secure_storage

## Implemented Modules

- PIN-based login
- Dashboard
- Patient list, create, update, delete
- Appointment calendar, create, update, cancel
- Visit create, update, photo upload, photo delete
- Prescription PDF generation and viewing
- Admin panel for staff, masters, and activity logs

## Run

```bash
flutter pub get
flutter run --dart-define=BASE_URL=http://10.0.2.2:8000/api/v1
```

For a physical Android device, replace `10.0.2.2` with your machine's LAN IP.

## Validation

```bash
flutter analyze
flutter test
```
