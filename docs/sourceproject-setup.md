# SourceProject setup

`SourceProject` is the Godot project root. `scenes/main.tscn` is the configured entry scene and instantiates `scenes/test.tscn`, which is the isolated visual-test surface. The monitor test asset uses `shaders/monitor_border.gdshader`; its material parameters are stored on the `TextureRect` in `test.tscn`.

`components/animated_logo.tscn` is a reusable two-layer logo component. It loops the eight `logo (n).png` frames with a 500 ms cross-fade between each pair and a smooth 180-degree rotation per full eight-frame cycle; `frame_duration` is exposed for per-instance adjustment. Its test-scene instance uses 50% scale.

The component is instantiated in `scenes/test.tscn` for visual review.

`components/countdown.tscn` is a reusable countdown component. It renders a Persian remaining-time value over `assets/pics/ui/countdown.png`, emits `finished` at zero, and provides `place_bottom_right()` for the standard small bottom-right placement.

`GameSettings` is an autoload that persists the player profile to `user://settings.cfg`. The selected avatar determines the level-image set: girl avatars resolve `assets/pics/levels/{level}/g`; boy avatars resolve `assets/pics/levels/{level}/b`. Scenes request assets by name through `GameSettings`, rather than hard-coding a world-specific path. `scenes/level1.tscn` requests `l1-0`.

`scenes/main.tscn` always opens the map. On the first entry to Level 1, the settings panel remains open until the player saves their name, avatar, and audio preference; the game then starts with the avatar's matching image set.

`components/drag_gesture_hint.gd` gives a two-second drag demonstration on the first display of the map, room, and laptop chat. The three completed demonstrations are stored in `user://settings.cfg`.
