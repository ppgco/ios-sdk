# Changelog

## 4.5.0

### Changed

- Improve statistics reporting reliability.
- Improve notification processing and image attachment handling.
- Improve error reporting for subscriber and beacon requests.

### Fixed

- Fix notification categories handling and beacon date formatting.

### Deprecated

- Deprecate manual delivery reporting and app lifecycle forwarding methods, which are no longer required.
- Deprecate `getEvents()` because event history is no longer retained.

### Migration

- Update the Notification Service Extension using the [current integration example](README.md#create-a-notification-service-extension).
- Remove manual calls to `PPGapplicationDidBecomeActive()`, `PPGdidReceiveRemoteNotification(...)`, and `registerNotificationDeliveredFromUserInfo(...)`.
- Do not use `getEvents()` as event history; it now returns pending events only.
