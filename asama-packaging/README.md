# Asama packaging (host-agent DCGM)

This directory is **Asama-only**. It is not NVIDIA upstream `packaging/`.
Do not merge these paths into upstream PRs.

It builds `asama-dcgm-exporter` (identity / health / analysis instances, Asama counters).

## Publish

`EXPORTER_VERSION` in `hack/versions.env` is **4.8.3** on this pin.

Do not pick a number. In Actions, run **Publish asama-dcgm-exporter** on the branch you want, choose **test** or **production**. The workflow reads existing git tags and uses the next `N` (`001`, `002`, …).

That creates:

```text
v4.8.3-asama-test-N   # testing Pulp
v4.8.3-asama-N        # production Pulp
```

Debian `Version` uses one hyphen (`4.8.3-asama.test.N` / `4.8.3-asama.N`).
RPM `Version` is `4.8.3`; `Release` is `asama.test.N` or `asama.N`.

Pushing a numbered tag still works if you need to pin `N` by hand.

Workflow: `.github/workflows/publish-asama-dcgm-exporter.yml`
