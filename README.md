# PushPushGo iOS SDKs

This repository contains the iOS SDKs maintained by PushPushGo.

## SDKs

- **[Push Notifications SDK](Sources/PPG_framework/README.md)** - push notifications, subscriber management, beacons
- **[In-App Messages SDK](Sources/PPG_InAppMessages/README.md)** - targeted in-app messages
- **[Live Activities SDK](Sources/PPG_LiveActivities/README.md)** - real-time activity tracking on the Lock Screen and in the Dynamic Island

## Credentials

The project ID can be found in the PushPushGo dashboard. An API key can be generated under *Project settings → Integration → Mobile*.

## Shared App Group

The Push Notifications and Live Activities SDKs require an App Group identifier. Create an App Group and share the same identifier between the app and its Notification Service and Widget extensions.

See the [Push Notifications setup guide](Sources/PPG_framework/README.md#add-required-capabilities) and [Live Activities setup guide](Sources/PPG_LiveActivities/README.md#step-1-app-group) for instructions on creating and configuring the App Group.
