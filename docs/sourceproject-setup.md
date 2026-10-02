# SourceProject setup

`SourceProject` is the Godot project root. `scenes/main.tscn` is the configured entry scene and instantiates `scenes/test.tscn`, which is the isolated visual-test surface. The monitor test asset uses `shaders/monitor_border.gdshader`; its material parameters are stored on the `TextureRect` in `test.tscn`.

`components/animated_logo.tscn` is a reusable two-layer logo component. It loops the eight `logo (n).png` frames with a 500 ms cross-fade between each pair and a smooth 180-degree rotation per full eight-frame cycle; `frame_duration` is exposed for per-instance adjustment. Its test-scene instance uses 50% scale.

The component is instantiated in `scenes/test.tscn` for visual review.

`components/countdown.tscn` is a reusable countdown component. It renders a Persian remaining-time value over `assets/pics/ui/countdown.png`, emits `finished` at zero, and provides `place_bottom_right()` for the standard small bottom-right placement.

`GameSettings` is an autoload that persists the selected player world to `user://settings.cfg`. `girl` resolves level images from `assets/pics/levels/g`; `boy` resolves them from `assets/pics/levels/b`. Scenes request assets by name through `GameSettings`, rather than hard-coding a world-specific path. `scenes/level1.tscn` requests `l1-0`.

On the first launch, `scenes/main.tscn` opens `scenes/world_selection.tscn`. Selecting a world saves the choice through `GameSettings` and opens Level 1. Later launches use the saved world and open Level 1 directly.
