// Centralized feature flags for Firestore path migration
// Toggle carefully; defaults keep current behavior (root collections only)

class FeatureFlags {
  // Phase 1: keep false to avoid UI impact; turn on after data is ready
  static const bool useNestedCollections = true; // clinics/{clinicId}/...

  // During migration, write to both root and nested using same docId
  static const bool dualWriteEnabled = false;

  // During migration, read primary first, then fallback to legacy root
  static const bool dualReadFallbackEnabled = false;
}

