# Architecture

`MissionReader` inspects the Dock/WindowManager Mission Control accessibility subtree, excluding Spaces. It uses bounded traversal and cross-process AX timeouts. Reads run on a serial worker queue, outside the event-tap callback.

Each thumbnail is matched through a unique exact transformed WindowServer rectangle to a real window ID and owner PID, then independently checked against the owning app's AXWindows. Titles alone never authorize destructive operations. Ambiguous or stale bindings fail closed. The reader includes accessory apps when their actual windows correspond to thumbnails.

A read-only private bridge, `_AXUIElementGetWindow`, is dynamically looked up for real application AXWindows. It is not used to treat the shared Mission Control proxy container as a real app window. Availability is optional; missing IDs disable destructive actions for unresolved windows. This is an experimental system integration and a material App Store compatibility constraint.

`InputRouter` maps event characters and modifier flags to actions and tracks physical key-up suppression. `MissionController` keeps the selected real window identity across snapshot reorderings and proxy reuse. Before executing it reads a fresh snapshot, checks identity and current authorization epoch, and rechecks enabled/trusted/active/fresh state. Settings changes, permission loss, Escape, normal Mission Control clicks and shutdown invalidate queued work.

`WindowActionExecutor` uses AX close buttons, AX minimization and hide attributes, AXPress for opening a thumbnail, and normal or forced NSRunningApplication termination. Normal Finder termination is rejected. A successful request is not proof of completion: an app may present a confirmation or decline to close.

Settings are stored in local UserDefaults. Login-at-start uses SMAppService. Sparkle is embedded for configured direct-distribution updates; the `APP_STORE` capability build excludes Sparkle and the known private bridge, but is not a working full-feature Store edition.
