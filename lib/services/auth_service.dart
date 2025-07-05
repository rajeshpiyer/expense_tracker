import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../database/database_helper.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  // Initialize the auth service and check for existing session
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    
    if (userId != null) {
      _currentUser = await _databaseHelper.getUser(userId);
      
      // If user exists in database, update last login
      if (_currentUser != null) {
        final updatedUser = _currentUser!.copyWith(
          lastLoginAt: DateTime.now(),
        );
        await _databaseHelper.updateUser(updatedUser);
        _currentUser = updatedUser;
      } else {
        // Clear invalid session
        await _clearSession();
      }
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Create or update user in database
      final now = DateTime.now();
      final user = User(
        id: googleUser.id,
        name: googleUser.displayName ?? '',
        email: googleUser.email,
        photoUrl: googleUser.photoUrl,
        createdAt: now,
        lastLoginAt: now,
      );

      // Check if user already exists
      final existingUser = await _databaseHelper.getUser(user.id);
      
      if (existingUser != null) {
        // Update existing user's last login
        final updatedUser = existingUser.copyWith(
          name: user.name,
          email: user.email,
          photoUrl: user.photoUrl,
          lastLoginAt: now,
        );
        await _databaseHelper.updateUser(updatedUser);
        _currentUser = updatedUser;
      } else {
        // Insert new user
        await _databaseHelper.insertUser(user);
        _currentUser = user;
      }

      // Save session
      await _saveSession(_currentUser!.id);
      
      return _currentUser;
    } catch (error) {
      print('Error signing in with Google: $error');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _clearSession();
      _currentUser = null;
    } catch (error) {
      print('Error signing out: $error');
    }
  }

  // Save user session
  Future<void> _saveSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
  }

  // Clear user session
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
  }

  // Check if user is currently signed in with Google
  Future<bool> isGoogleSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  // Get current Google user (if signed in)
  GoogleSignInAccount? get currentGoogleUser => _googleSignIn.currentUser;

  // Silent sign in (try to sign in without user interaction)
  Future<User?> silentSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      
      if (googleUser != null) {
        // Update user info if needed
        final existingUser = await _databaseHelper.getUser(googleUser.id);
        
        if (existingUser != null) {
          final updatedUser = existingUser.copyWith(
            lastLoginAt: DateTime.now(),
          );
          await _databaseHelper.updateUser(updatedUser);
          _currentUser = updatedUser;
          await _saveSession(_currentUser!.id);
          return _currentUser;
        }
      }
      
      return null;
    } catch (error) {
      print('Error during silent sign in: $error');
      return null;
    }
  }

  // Refresh current user data from database
  Future<void> refreshCurrentUser() async {
    if (_currentUser != null) {
      _currentUser = await _databaseHelper.getUser(_currentUser!.id);
    }
  }
}
