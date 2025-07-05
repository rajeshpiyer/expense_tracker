# Firebase Setup Instructions

This project uses Firebase for Google Sign-In authentication. You need to set up your own Firebase project and configuration files.

## 🔥 Firebase Configuration Required

The following files are **NOT** included in the repository for security reasons:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist` (if iOS support is added)

## 📋 Setup Steps

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name (e.g., "expense-tracker-[your-name]")
4. Follow the setup wizard

### 2. Add Android App
1. In Firebase Console, click "Add app" → Android
2. **Package name**: `com.expensetracker.expense_tracker`
3. **App nickname**: Expense Tracker (optional)
4. **Debug signing certificate SHA-1**: Generate using the command below

### 3. Generate SHA-1 Certificate
Run this command in your project root:
```bash
cd android
./gradlew signingReport
```
Copy the SHA-1 from the debug keystore.

### 4. Enable Google Sign-In
1. In Firebase Console → Authentication
2. Click "Get started" if not set up
3. Go to "Sign-in method" tab
4. Enable "Google" provider
5. Set your support email
6. Save

### 5. Download Configuration File
1. In Firebase Console → Project Settings
2. Scroll to "Your apps"
3. Click download icon for Android app
4. Save as `android/app/google-services.json`

### 6. Verify Setup
The `google-services.json` should contain:
- `oauth_client` array with at least one entry
- Your package name: `com.expensetracker.expense_tracker`
- Your SHA-1 certificate hash

## 🔒 Security Notes

- **Never commit** `google-services.json` to version control
- Each developer needs their own Firebase project for development
- Use different Firebase projects for development/staging/production
- The template file `android/app/google-services.json.template` shows the required structure

## 🚀 Running the App

After setting up Firebase:
1. Place `google-services.json` in `android/app/`
2. Run `flutter clean`
3. Run `flutter run`

## ❗ Troubleshooting

**Google Sign-In Error Code 10 (DEVELOPER_ERROR)**:
- Verify SHA-1 certificate is correct
- Ensure Google Sign-In is enabled in Firebase Console
- Check package name matches exactly
- Verify `oauth_client` array is not empty in `google-services.json`

**Build Errors**:
- Ensure `google-services.json` is in the correct location
- Run `flutter clean` after adding the file
- Check that Firebase project has Google Sign-In enabled
