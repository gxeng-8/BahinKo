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
