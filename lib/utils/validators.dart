/// Form validators shared by several screens.
///
/// Each returns null when the value is valid, or a short error message to
/// show under the field (the convention TextFormField.validator expects).
library;

/// A person's name: required, 2–30 characters, letters/spaces/.-' only.
/// Used for your own name, joining a group, and adding guests.
String? validatePersonName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Enter a name';
  if (name.length < 2) return 'Name is too short';
  if (name.length > 30) return 'Keep it under 30 characters';
  if (!RegExp(r"^[A-Za-zÀ-ÿñÑ .'-]+$").hasMatch(name)) {
    return 'Use letters only';
  }
  return null;
}

/// Usernames: 3-20 characters, lowercase letters, numbers, dots or
/// underscores, starting with a letter ("yumi", "renz.d", "ana_23").
String? validateUsername(String? value) {
  final u = normalizeUsername(value ?? '');
  if (u.isEmpty) return 'Choose a username';
  if (u.length < 3) return 'At least 3 characters';
  if (u.length > 20) return '20 characters at most';
  if (!RegExp(r'^[a-z][a-z0-9._]*$').hasMatch(u)) {
    return 'Letters, numbers, . or _ (start with a letter)';
  }
  return null;
}

/// "@Yumi " -> "yumi".
String normalizeUsername(String value) =>
    value.trim().toLowerCase().replaceFirst('@', '');

/// The sign-in PIN: exactly 6 digits, and not an easy one to guess.
String? validateNewPin(String? value) {
  final pin = value ?? '';
  if (!RegExp(r'^\d{6}$').hasMatch(pin)) return 'Enter 6 digits';
  if (RegExp(r'^(\d)\1{5}$').hasMatch(pin) ||
      '0123456789'.contains(pin) ||
      '9876543210'.contains(pin)) {
    return 'Too easy to guess (like 111111 or 123456)';
  }
  return null;
}
