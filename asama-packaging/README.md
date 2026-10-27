# Asama packaging (host-agent DCGM)

This directory is **Asama-only**. It is not NVIDIA upstream `packaging/`.
Do not merge these paths into upstream PRs.

It builds `asama-dcgm-exporter` (identity / health / analysis instances, Asama counters).

## Publish

`EXPORTER_VERSION` in `hack/versions.env` is **4.8.4** on this pin.

The git tag is the Asama version. Upstream comes from `EXPORTER_VERSION` at that commit. The package name is `asama-dcgm-exporter`, so the version does not repeat `asama`.

```text
v1.2.3         # production
v1.2.3-test1   # testing
```

With `EXPORTER_VERSION=4.8.4`, those become Debian `4.8.4-1.2.3-1` and `4.8.4-1.2.3~test1-1`. RPM `Version` is `4.8.4`. RPM `Release` is `1.2.3` or `1.2.3~test1`. The `~` makes the test build sort before that same release.

A manual run takes the same Asama version (`1.2.3` or `1.2.3-test1`) and pushes that tag.

Workflow: `.github/workflows/publish-asama-dcgm-exporter.yml`
