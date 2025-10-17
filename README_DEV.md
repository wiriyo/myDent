# MyDent Web Development Notes

## Fixed Flutter Web port

Flutter web development now runs on a fixed port so that QZ Tray can whitelist the origin. Launch the dev server with VS Code (profile **Flutter Web (fixed port)**) or run:

```bash
flutter run -d chrome --web-port 55390 --web-hostname localhost
```

This will expose the app at `http://localhost:55390`. Make sure the same origin is added to QZ Tray's **Allowed Origins** (and whitelist `http://127.0.0.1:55390` if you access it via loopback) so that printing works reliably and QZ Tray can be allowed through QZ Tray Site Manager / QZ Tray security prompts.

Allow this port in QZ Tray (and any firewall/endpoint protection) so that the browser → QZ Tray bridge can connect without intermittent `qz_bridge_missing` errors.
