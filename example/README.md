# flywheel_carousel_example

A new Flutter project.

## End-to-end tests

On-simulator integration suite (drives this app plus dedicated fixture widgets, and records frame
timing, settle latency and itemBuilder calls per frame). From `example/`:

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/flywheel_e2e_test.dart -d <ios-simulator-id>
```

Metrics land in `example/build/e2e/metrics.json` (a per-scenario table is also printed to stdout).
Scenarios pinning known defects (B4/B5/B6, S1/S2/S3/S9) are skipped; add
`--dart-define=E2E_RUN_KNOWN_BUGS=true` to run them and see them fail.
