abstract final class SyncEndpoint {
  static const baseUrl = String.fromEnvironment('NYLA_SYNC_BASE_URL');

  static bool get isConfigured {
    final uri = Uri.tryParse(baseUrl);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
