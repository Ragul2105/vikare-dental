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

### On macOS

If you want a tablet-sized simulator without Android Studio, the easiest path is the iOS simulator. This works if you only need to develop and test the UI on a larger screen:

```bash
# If the ios/ folder is missing, generate the platform files once.
flutter create .

flutter devices
flutter run -d ios --dart-define=BASE_URL=http://localhost:8000/api/v1
```

Use `http://localhost:8000/api/v1` from the iOS simulator because it can reach services on your Mac directly. Keep `10.0.2.2` only for the Android emulator.

If your target is specifically an Android tablet, you will need the Android SDK/emulator tools. Android Studio is the simplest way to install those, but the Flutter SDK itself is always required.

If you do not have Flutter installed yet, install the Flutter SDK first. If you want the iPhone/iPad simulator, you also need Xcode installed from the App Store.

## Validation

```bash
flutter analyze
flutter test
```
