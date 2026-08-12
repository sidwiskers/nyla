import '../../core/notifications/notification_config.dart';
import '../database/app_database.dart';

class PreferencesRepository {
  PreferencesRepository(this.database);

  static const _notificationKey = 'notifications.config.v1';

  final AppDatabase database;

  Stream<NotificationConfig> watchNotificationConfig() =>
      database.watchPreference(_notificationKey).map(NotificationConfig.decode);

  Future<NotificationConfig> notificationConfig() async =>
      NotificationConfig.decode(await database.preference(_notificationKey));

  Future<void> setNotificationConfig(NotificationConfig value) =>
      database.setPreference(_notificationKey, value.encode());
}
