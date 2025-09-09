// Simple global holder for current clinic context.
// Set by Auth provider upon verification/login; read by services that need clinic scope.

class ClinicContext {
  static String? activeClinicId;
}

