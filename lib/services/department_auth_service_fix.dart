// FIX: Replace lines 279-285 in department_auth_service.dart with this:

  Future<void> _saveUser(EnhancedUser user, String token) async {
    // Ensure prefs is initialized
    _prefs = await SharedPreferences.getInstance();
    
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_deptKey, user.department.name);
    await _prefs.setString(_roleKey, user.role.name);
  }
