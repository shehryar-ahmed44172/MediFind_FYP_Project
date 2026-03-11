/// Authentication Form Validators
/// Handles email, phone, password, and other credential validations

class AuthValidator {
  /// Validate email format
  /// Returns error message or null if valid
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return "Email is required";
    }

    // Email regex pattern
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return "Please enter a valid email address";
    }

    return null;
  }

  /// Validate phone number format (Pakistani and international)
  /// Accepts formats: +923001234567, 03001234567, +1-234-567-8900
  static String? validatePhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return "Phone number is required";
    }

    // Remove common formatting characters
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-().]'), '');

    // Check if it's at least 10 digits
    final digitOnly = cleanPhone.replaceAll(RegExp(r'[^\d]'), '');

    if (digitOnly.length < 10) {
      return "Phone number must have at least 10 digits";
    }

    if (digitOnly.length > 15) {
      return "Phone number is too long";
    }

    // Pakistani phone number pattern
    if (phoneNumber.contains('03') || phoneNumber.contains('+92')) {
      final pakistaniRegex = RegExp(r'^[\+]?92[03][0-9]{8}$|^0[03][0-9]{8}$');
      if (!pakistaniRegex.hasMatch(phoneNumber.replaceAll('-', ''))) {
        // Allow more flexible validation for Pakistani numbers
        if (!digitOnly.startsWith('92') && !digitOnly.startsWith('0')) {
          return "Invalid Pakistani phone number format";
        }
      }
    }

    return null;
  }

  /// Validate password strength
  /// Requirements:
  /// - Minimum 8 characters
  /// - At least one uppercase letter
  /// - At least one lowercase letter
  /// - At least one number
  /// - At least one special character (!@#$%^&*)
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return "Password is required";
    }

    if (password.length < 8) {
      return "Password must be at least 8 characters long";
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      return "Password must contain at least one uppercase letter";
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      return "Password must contain at least one lowercase letter";
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      return "Password must contain at least one number";
    }

    if (!password.contains(RegExp(r'[!@#$%^&*]'))) {
      return "Password must contain at least one special character (!@#\$%^&*)";
    }

    return null;
  }

  /// Validate password confirmation matches original
  static String? validatePasswordMatch(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return "Please confirm your password";
    }

    if (password != confirmPassword) {
      return "Passwords do not match";
    }

    return null;
  }

  /// Validate full name (at least 2 characters, no special characters)
  static String? validateFullName(String? fullName) {
    if (fullName == null || fullName.isEmpty) {
      return "Full name is required";
    }

    if (fullName.length < 2) {
      return "Name must be at least 2 characters long";
    }

    if (fullName.length > 50) {
      return "Name cannot exceed 50 characters";
    }

    // Allow letters, spaces, hyphens, and apostrophes
    if (!RegExp(r"^[a-zA-Z\s\-']+(?: [a-zA-Z\s\-']+)*$").hasMatch(fullName.trim())) {
      return "Name contains invalid characters";
    }

    return null;
  }

  /// Validate user role
  static String? validateRole(String? role) {
    const validRoles = ['PATIENT', 'RESPONDER', 'CAREGIVER', 'ADMIN'];

    if (role == null || role.isEmpty) {
      return "Please select a role";
    }

    if (!validRoles.contains(role)) {
      return "Invalid role selected";
    }

    return null;
  }
}
