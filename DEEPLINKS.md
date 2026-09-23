# URL handling in PushPushGo iOS SDK

This guide explains what happens when a user taps a notification containing a
regular web link, a custom-scheme deep link, or a Universal Link.

The default behavior described below applies when no custom
`NotificationClickHandler` is configured. If you provide one, your app becomes
responsible for routing or opening every supported notification URL.

---

## Table of contents

- [Default URL handling](#default-url-handling)
- [Supported URL schemes](#supported-url-schemes)
- [Custom-scheme deep links](#custom-scheme-deep-links)
- [Universal Links](#universal-links)
- [Custom notification handling](#custom-notification-handling)
- [Troubleshooting](#troubleshooting)

---

## Default URL handling

The default behavior depends on the type of URL attached to the notification:

| URL type | Default behavior |
| --- | --- |
| Regular web link | Opens in the user's browser. |
| Custom-scheme deep link | Opens in an app registered for that URL scheme. |
| Universal Link | Forwards the link to the app's AppDelegate; see the lifecycle limitations below. |

Universal Links are forwarded directly to
`application(_:continue:restorationHandler:)` on the app's AppDelegate. If the
AppDelegate does not implement that method, the SDK opens the URL using the
system URL handling instead (`UIApplication.shared.open(url)`).

This default behavior only supports AppDelegate-based navigation.
Apps using UIKit scenes, SwiftUI, or custom navigation should provide a
`NotificationClickHandler` and route the URL themselves.

The AppDelegate behavior is retained for backward compatibility.

---

## Supported URL schemes

The SDK validates the URL scheme before passing a URL to either the default or
custom handler. The supported schemes default to `http`, `https`, and `app`.

To support a different scheme, add it to `PPGSupportedURLSchemes` in the main
app's `Info.plist`:

```xml
<key>PPGSupportedURLSchemes</key>
<array>
    <string>http</string>
    <string>https</string>
    <string>myapp</string>
</array>
```

Setting `PPGSupportedURLSchemes` replaces the default list. Include `http` and
`https` if the app should continue handling web links.

---

## Custom-scheme deep links

Custom URL schemes, such as `myapp://product/42`, can open a specific location
inside an app.

### Register the URL scheme

Add the scheme to `CFBundleURLTypes` in the main app's `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.example.myapp</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
    </dict>
</array>
```

The scheme must also be included in `PPGSupportedURLSchemes`, as described in
[Supported URL schemes](#supported-url-schemes).

### Handle the deep link

The default handler asks iOS to open the URL. iOS then delivers it to an app
registered for that scheme through the appropriate lifecycle callback.

**UIKit AppDelegate:**

```swift
func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
) -> Bool {
    MyRouter.handle(url)
}
```

**UIKit SceneDelegate:**

```swift
func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
    contexts.forEach { MyRouter.handle($0.url) }
}

func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
) {
    if let url = connectionOptions.urlContexts.first?.url {
        MyRouter.handle(url)
    }
}
```

**SwiftUI:**

```swift
WindowGroup {
    ContentView()
        .onOpenURL { url in
            MyRouter.handle(url)
        }
}
```

---

## Universal Links

Universal Links use regular web URLs to open content in an associated app.

To enable them:

1. Configure an `apple-app-site-association` (AASA) file for each website
   domain, defining the links the app should handle.
2. Add the **Associated Domains** capability to the app and include a matching
   entry, for example:

   ```text
   applinks:example.com
   ```

3. Configure the app to route the incoming URL using the default behavior
   described below or a custom `NotificationClickHandler`.

Follow Apple's
[Supporting associated domains](https://developer.apple.com/documentation/Xcode/supporting-associated-domains)
documentation for the current AASA format, hosting requirements, and app
configuration. For diagnostic guidance, see
[Debugging Universal Links](https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links).

### Default-handler behavior

For notification URLs configured as Universal Links, the default handler
passes the URL directly to the `application(_:continue:restorationHandler:)`
AppDelegate callback:

```swift
func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else {
        return false
    }

    return MyRouter.handle(url)
}
```

This behavior is retained for backward compatibility. It does not
dispatch the URL to a UIKit SceneDelegate or a SwiftUI URL handler. If an
existing AppDelegate implementation returns `false`, the SDK does not try to
open the URL again.

New integrations, apps using UIKit scenes or SwiftUI, and apps with custom
navigation should use a custom `NotificationClickHandler`.

---

## Custom notification handling

Provide a custom handler when the app should decide how notification URLs are
routed:

```swift
import PPG_framework

final class AppNotificationClickHandler: NotificationClickHandler {
    func handle(url: URL) {
        appRouter.handle(url)
    }
}

PPG.notificationClickHandler = AppNotificationClickHandler()
```

After configuring a custom handler, the SDK passes supported notification URLs
to it and does not open them automatically. The app is responsible for routing
or opening each URL.

To restore the default behavior:

```swift
PPG.notificationClickHandler = nil
```

See the
[`PPG_framework` integration guide](Sources/PPG_framework/README.md#configure-notification-url-handling)
for the complete SDK setup.

---

## Troubleshooting

- **A custom-scheme deep link does nothing.** Confirm that the scheme is listed
  in both `CFBundleURLTypes` and `PPGSupportedURLSchemes`.
- **A web link is ignored.** If `PPGSupportedURLSchemes` is configured, confirm
  that it includes `http` and `https`.
- **A Universal Link does not navigate inside the app.** Confirm that the AASA
  file and Associated Domains capability match. If the app uses UIKit scenes or
  SwiftUI, configure a custom `NotificationClickHandler`.
- **The legacy Universal Link callback is not invoked.** Confirm that
  `application(_:continue:restorationHandler:)` is implemented by the app's
  actual AppDelegate.
