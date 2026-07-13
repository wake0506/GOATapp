const bool enableVersionedCloudSync = bool.fromEnvironment(
  'ENABLE_VERSIONED_SYNC',
  defaultValue: bool.fromEnvironment(
    'GOAT_ENABLE_VERSIONED_CLOUD_SYNC',
    defaultValue: false,
  ),
);

class VersionedSyncRollout {
  final bool enabledByBuild;

  const VersionedSyncRollout({this.enabledByBuild = enableVersionedCloudSync});

  bool get isEnabled => enabledByBuild;
}
