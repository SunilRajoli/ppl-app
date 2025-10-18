// // lib/core/providers/auth_provider.dart
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';

// import '../models/user_model.dart';
// import '../services/api_service.dart';
// import '../services/storage_service.dart';

// /// Holds logged-in user, token, and auth flows.
// /// Matches your screens: login/register/change-password and mustChangePassword.
// class AuthProvider with ChangeNotifier {
//   final ApiService _api = ApiService();
//   final StorageService _storage = StorageService();

//   User? _user;
//   String? _token;
//   bool _isAuthenticated = false;
//   bool _isLoading = true;
//   bool _mustChangePassword = false;

//   User? get user => _user;
//   String? get token => _token;
//   bool get isAuthenticated => _isAuthenticated;
//   bool get isLoading => _isLoading;
//   bool get mustChangePassword => _mustChangePassword;
//   bool get isAdmin => (_user?.role?.toLowerCase() ?? '') == 'admin';

//   AuthProvider() {
//     _initAuth();
//   }

//   Future<void> _initAuth() async {
//     try {
//       _token = await _storage.getToken();
//       final userJson = await _storage.getUser();

//       if (_token != null && _token!.isNotEmpty && userJson != null) {
//         _user = User.fromJson(userJson);
//         _isAuthenticated = true;
//         _mustChangePassword = _user?.forcePasswordChange ?? false;
//       }
//     } catch (e, st) {
//       debugPrint('Auth init error: $e\n$st');
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   // ---------------------------
//   //               LOGIN
//   // ---------------------------
//   Future<Map<String, dynamic>> login({
//     required String email,
//     required String password,
//     String? role,
//   }) async {
//     try {
//       final res = await _api.login(email: email, password: password, role: role);

//       if (res['success'] == true) {
//         final data = res['data'] ?? res;
//         _token = data['token'] as String?;
//         final userJson = data['user'];
//         if (_token == null || userJson == null) {
//           return {'success': false, 'message': 'Invalid login response'};
//         }

//         _user = User.fromJson(userJson);
//         _isAuthenticated = true;
//         _mustChangePassword = (data['mustChangePassword'] == true) ||
//             (_user?.forcePasswordChange == true);

//         await _storage.saveToken(_token!);
//         await _storage.saveUser(_user!.toJson());

//         notifyListeners();
//         return {'success': true, 'mustChangePassword': _mustChangePassword};
//       }

//       return {
//         'success': false,
//         'message': res['message'] ?? 'Login failed',
//       };
//     } catch (e) {
//       return {'success': false, 'message': e.toString()};
//     }
//   }

//   // ---------------------------
//   //             REGISTER
//   // ---------------------------
//   Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
//     try {
//       final res = await _api.register(userData);

//       if (res['success'] == true) {
//         final data = res['data'] ?? res;
//         _token = data['token'] as String?;
//         final userJson = data['user'];
//         if (_token == null || userJson == null) {
//           return {'success': false, 'message': 'Invalid registration response'};
//         }

//         _user = User.fromJson(userJson);
//         _isAuthenticated = true;
//         _mustChangePassword = false;

//         await _storage.saveToken(_token!);
//         await _storage.saveUser(_user!.toJson());

//         notifyListeners();
//         return {'success': true};
//       }

//       return {
//         'success': false,
//         'message': res['message'] ?? 'Registration failed',
//       };
//     } catch (e) {
//       return {'success': false, 'message': e.toString()};
//     }
//   }

//   // ---------------------------
//   //             LOGOUT
//   // ---------------------------
//   Future<void> logout() async {
//     try {
//       // It's good practice to await the API call, but not critical if it fails.
//       await _api.logout();
//     } catch (e) {
//       debugPrint('Logout API error: $e');
//     } finally {
//       _user = null;
//       _token = null;
//       _isAuthenticated = false;
//       _mustChangePassword = false;

//       // ✅ FIX: Added 'await' to ensure storage is cleared before notifying listeners.
//       await _storage.clearToken();

//       notifyListeners();
//     }
//   }

//   // ---------------------------
//   //       CHANGE PASSWORD
//   // ---------------------------
//   Future<Map<String, dynamic>> changePassword({
//     String? currentPassword,
//     required String newPassword,
//   }) async {
//     try {
//       final res = await _api.changePassword(
//         currentPassword: currentPassword,
//         newPassword: newPassword,
//       );

//       if (res['success'] == true) {
//         _mustChangePassword = false;
//         if (_user != null) {
//           _user!.forcePasswordChange = false;
//           await _storage.saveUser(_user!.toJson());
//         }
//         notifyListeners();
//       }

//       return res;
//     } catch (e) {
//       return {'success': false, 'message': e.toString()};
//     }
//   }

//   // ---------------------------
//   //              PROFILE
//   // ---------------------------
//   Future<void> refreshProfile() async {
//     if (!_isAuthenticated) return;
//     try {
//       final res = await _api.getProfile();
//       final data = res['data'] ?? res;
//       if (data is Map && data['user'] != null) {
//         _user = User.fromJson(data['user']);
//         await _storage.saveUser(_user!.toJson());
//         notifyListeners();
//       }
//     } catch (e) {
//       debugPrint('Profile refresh error: $e');
//     }
//   }

//   // ---------------------------
//   //      MUST-CHANGE FLAG
//   // ---------------------------
//   void clearMustChangePassword() {
//     _mustChangePassword = false;
//     if (_user != null) {
//       _user!.forcePasswordChange = false;
//       _storage.saveUser(_user!.toJson());
//     }
//     notifyListeners();
//   }

//   void setUser(User user) async {
//     _user = user;
//     _isAuthenticated = true;
//     try {
//       await _storage.saveUser(user.toJson());
//     } catch (_) {}
//     notifyListeners();
//   }
// }

// lib/core/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Holds logged-in user, token, and auth flows.
/// Matches your screens: login/register/change-password and mustChangePassword.
class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  User? _user;
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _mustChangePassword = false;

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get mustChangePassword => _mustChangePassword;
  bool get isAdmin => (_user?.role?.toLowerCase() ?? '') == 'admin';

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      _token = await _storage.getToken();
      final userJson = await _storage.getUser();

      if (_token != null && _token!.isNotEmpty && userJson != null) {
        _user = User.fromJson(userJson);
        _isAuthenticated = true;
        _mustChangePassword = _user?.forcePasswordChange ?? false;
      }
    } catch (e, st) {
      debugPrint('Auth init error: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------
  //               LOGIN
  // ---------------------------
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? role,
  }) async {
    try {
      final res = await _api.login(email: email, password: password, role: role);

      if (res['success'] == true) {
        final data = res['data'] ?? res;
        _token = data['token'] as String?;
        final userJson = data['user'];
        if (_token == null || userJson == null) {
          return {'success': false, 'message': 'Invalid login response'};
        }

        _user = User.fromJson(userJson);
        _isAuthenticated = true;
        _mustChangePassword = (data['mustChangePassword'] == true) ||
            (_user?.forcePasswordChange == true);

        await _storage.saveToken(_token!);
        await _storage.saveUser(_user!.toJson());

        notifyListeners();
        return {'success': true, 'mustChangePassword': _mustChangePassword};
      }

      return {
        'success': false,
        'message': res['message'] ?? 'Login failed',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ---------------------------
  //             REGISTER
  // ---------------------------
  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final res = await _api.register(userData);

      // ✅ FIX: Registration doesn't return a token - user must verify email first
      // Just return the success response without trying to authenticate
      if (res['success'] == true) {
        return {
          'success': true,
          'message': res['message'] ?? 'Registration successful. Please check your email.',
        };
      }

      return {
        'success': false,
        'message': res['message'] ?? 'Registration failed',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ---------------------------
  //             LOGOUT
  // ---------------------------
  Future<void> logout() async {
    try {
      // It's good practice to await the API call, but not critical if it fails.
      await _api.logout();
    } catch (e) {
      debugPrint('Logout API error: $e');
    } finally {
      debugPrint('AuthProvider: Clearing authentication state');
      _user = null;
      _token = null;
      _isAuthenticated = false;
      _mustChangePassword = false;

      await _storage.clearToken();
      
      // Mark that this is a logout so we skip splash screen on next launch
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ppl-from-logout', true);

      debugPrint('AuthProvider: Authentication state cleared, notifying listeners');
      notifyListeners();
    }
  }

  // ---------------------------
  //       CHANGE PASSWORD
  // ---------------------------
  Future<Map<String, dynamic>> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (res['success'] == true) {
        _mustChangePassword = false;
        if (_user != null) {
          _user!.forcePasswordChange = false;
          await _storage.saveUser(_user!.toJson());
        }
        notifyListeners();
      }

      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ---------------------------
  //              PROFILE
  // ---------------------------
  Future<void> refreshProfile() async {
    if (!_isAuthenticated) return;
    try {
      final res = await _api.getProfile();
      final data = res['data'] ?? res;
      if (data is Map && data['user'] != null) {
        _user = User.fromJson(data['user']);
        await _storage.saveUser(_user!.toJson());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Profile refresh error: $e');
    }
  }

  // ---------------------------
  //      MUST-CHANGE FLAG
  // ---------------------------
  void clearMustChangePassword() {
    _mustChangePassword = false;
    if (_user != null) {
      _user!.forcePasswordChange = false;
      _storage.saveUser(_user!.toJson());
    }
    notifyListeners();
  }

  void setUser(User user) async {
    _user = user;
    _isAuthenticated = true;
    try {
      await _storage.saveUser(user.toJson());
    } catch (_) {}
    notifyListeners();
  }

  // OAuth helper method
  Future<void> setTokenAndUser(String token, Map<String, dynamic> userJson) async {
    _token = token;
    _user = User.fromJson(userJson);
    _isAuthenticated = true;
    _mustChangePassword = _user?.forcePasswordChange ?? false;

    try {
      await _storage.saveToken(token);
      await _storage.saveUser(userJson);
    } catch (e) {
      debugPrint('Error saving OAuth data: $e');
    }
    notifyListeners();
  }
}