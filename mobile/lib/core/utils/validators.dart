/// Shared form validators, so every screen's form gives consistent
/// messages instead of each one inventing its own wording.
class AppValidators {
  AppValidators._();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "L'email est requis.";
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Entrez un email valide.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis.';
    }
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères.';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le téléphone est requis.';
    }
    if (value.trim().length < 6) {
      return 'Entrez un numéro de téléphone valide.';
    }
    return null;
  }

  static String? required(String? value, String fieldLabel) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel est requis.';
    }
    return null;
  }
}
