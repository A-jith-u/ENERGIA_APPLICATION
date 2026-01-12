// Validation utilities for user input

/// Email validation - checks for valid email format and common patterns
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email is required';
  }

  final email = value.trim();

  // Basic email pattern check
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  if (!emailRegex.hasMatch(email)) {
    return 'Invalid email format (e.g., user@example.com)';
  }

  // Check for at least one dot after @
  if (!email.contains('.')) {
    return 'Invalid email - must contain domain';
  }

  // Reject disposable email patterns
  final disposableDomains = [
    'tempmail',
    'throwaway',
    'guerrillamail',
    '10minutemail',
    'mailinator',
  ];

  final domain = email.split('@')[1].toLowerCase();
  for (final disposable in disposableDomains) {
    if (domain.contains(disposable)) {
      return 'Please use a valid institutional email';
    }
  }

  return null;
}

/// Phone number validation - checks for 10 digit Indian phone numbers
String? validatePhone(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Phone number is required';
  }

  final phone = value.trim().replaceAll(RegExp(r'\D'), '');

  if (phone.length != 10) {
    return 'Phone number must be 10 digits';
  }

  // Check for all same digits (e.g., 9999999999)
  if (phone.split('').toSet().length == 1) {
    return 'Invalid phone number';
  }

  // Check if it starts with valid digit (6-9 for Indian numbers)
  final firstDigit = int.parse(phone[0]);
  if (firstDigit < 6 || firstDigit > 9) {
    return 'Phone number must start with 6-9';
  }

  return null;
}

/// KTU ID validation - checks for valid KTU ID format
String? validateKtuId(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'KTU ID is required';
  }

  final ktuId = value.trim().toUpperCase();

  // Valid KTU ID patterns:
  // IDK21CS001, IDK22CS001, etc.
  // LIDK21CS001, LIDK22CS001, etc.
  final ktuRegex = RegExp(
    r'^(IDK|LIDK)\d{2}(CS|EC|ME|EE|CE|AD|IT)\d{3,4}$',
  );

  if (!ktuRegex.hasMatch(ktuId)) {
    return 'Invalid KTU ID format\nValid formats:\n• IDK22CS004\n• LIDK22CS070';
  }

  // Additional check for year (should be reasonable)
  final yearStr = ktuId.substring(
    ktuId.startsWith('LIDK') ? 4 : 3,
    (ktuId.startsWith('LIDK') ? 4 : 3) + 2,
  );
  final year = int.parse(yearStr);

  // Year should be between 2015 and current year + 1
  final currentYear = DateTime.now().year;
  final twoDigitYear = currentYear % 100;

  if (year < 15 || year > twoDigitYear + 1) {
    return 'KTU ID year must be between 2015 and ${currentYear + 1}';
  }

  return null;
}

/// Validates KTU ID with custom error messages
String? validateKtuIdWithExamples(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'KTU ID is required';
  }

  final ktuId = value.trim().toUpperCase();

  // Only IDK and LIDK prefixes are valid
  final validPrefixes = ['IDK', 'LIDK'];
  bool hasValidPrefix = false;

  for (final prefix in validPrefixes) {
    if (ktuId.startsWith(prefix)) {
      hasValidPrefix = true;
      break;
    }
  }

  if (!hasValidPrefix) {
    return 'KTU ID must start with IDK or LIDK\nValid examples:\n✓ IDK22CS004\n✓ LIDK22CS070';
  }

  // Valid KTU ID patterns
  final ktuRegex = RegExp(
    r'^(IDK|LIDK)\d{2}(CS|EC|ME|EE|CE|AD|IT)\d{3,4}$',
  );

  if (!ktuRegex.hasMatch(ktuId)) {
    return 'Invalid KTU ID format\nValid examples:\n✓ IDK22CS004\n✓ LIDK22CS070\nFormat: {PREFIX}{YY}{DEPT}{NUM}';
  }

  return null;
}

/// Full name validation
String? validateFullName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Full name is required';
  }

  final name = value.trim();

  if (name.length < 3) {
    return 'Name must be at least 3 characters';
  }

  if (name.length > 100) {
    return 'Name is too long';
  }

  // Check for at least one space (first and last name)
  if (!name.contains(' ')) {
    return 'Please enter first and last name';
  }

  // Check for invalid characters
  final nameRegex = RegExp(r"^[a-zA-Z\s\-\.']+$");
  if (!nameRegex.hasMatch(name)) {
    return 'Name contains invalid characters';
  }

  return null;
}

/// Validate all user fields
Map<String, String?> validateUserForm({
  required String name,
  required String email,
  required String phone,
  required String? ktuId,
  required String role,
}) {
  final errors = <String, String?>{};

  errors['name'] = validateFullName(name);
  errors['email'] = validateEmail(email);
  errors['phone'] = validatePhone(phone);

  if (role == 'Class Representative' && ktuId != null) {
    errors['ktuId'] = validateKtuIdWithExamples(ktuId);
  }

  return errors;
}
