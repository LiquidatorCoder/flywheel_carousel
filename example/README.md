# flywheel_carousel_example

Demo app for `flywheel_carousel`. Four tabs: **Cards**, **Icons**, **No loop** and **Controls**
(controller, tap-to-select, semantics). Light and dark themes follow the system setting.

```sh
flutter run
```

## End-to-end tests

On-simulator integration suite (drives this app plus dedicated fixture widgets, and records frame
timing, settle latency and itemBuilder calls per frame). From `example/`:

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/flywheel_e2e_test.dart -d <ios-simulator-id>
```

Scenarios, briefly:

- **E1-E3, E7** launch, short and one-page drags, loop wrap.
- **E4-E6, E9** flings, gentle nudges, non-loop clamping, catching a coasting wheel.
- **E8, E14** tab switching and landscape layout.
- **E10-E13, E16** tick counting, slot placement, state identity, builder calls per frame.
- **E15** performance soak. **E17-E18** tap-to-select and controller moves.

Scenarios pinning known defects (B4/B5/B6, S1/S2/S3/S9) are skipped; add
`--dart-define=E2E_RUN_KNOWN_BUGS=true` to run them and see them fail.

### Reading `build/e2e/metrics.json`

Metrics land in `example/build/e2e/metrics.json` (a per-scenario table is also printed to stdout).
The file maps a scenario name to its numbers, for example:

- `settle_ms`: time from release until the wheel is idle on an integer page.
- `builder_calls_per_frame`: `itemBuilder` calls divided by frames (should stay low; cards are built
  per page crossing, not per frame).
- frame timing: average and worst build/raster times and the count of frames over 16.7 ms (jank).
- scenario extras such as `pages_travelled`, `tap_to_selected_ms` or `next_1_ms`.
