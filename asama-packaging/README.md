# Asama packaging (host-agent DCGM)

This directory is **Asama-only**. It is not NVIDIA upstream `packaging/`.
Do not merge these paths into upstream PRs.

It builds `asama-dcgm-exporter` (identity / health / analysis instances, Asama counters).

## Git tags

`EXPORTER_VERSION` in `hack/versions.env` is **4.8.3** on this pin.

```text
v4.8.3-asama-test-001   # testing Pulp
v4.8.3-asama-001        # production Pulp
```

Debian `Version` uses one hyphen (`4.8.3-asama.test.001` / `4.8.3-asama.001`).
RPM `Version` is `4.8.3`; `Release` is `asama.test.001` or `asama.001`.

Workflow: `.github/workflows/publish-asama-dcgm-exporter.yml`
