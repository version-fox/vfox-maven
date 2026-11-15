# End-to-end check and dev container

[中文](zh-CN/e2e.md) | [English](e2e.md)

The offline tests cannot tell whether vfox installs a real Maven, so `tests/e2e/run.sh` does that. It runs in the e2e image (`tests/e2e/Dockerfile`), which holds Ubuntu, a Java runtime, zip, and the vfox release the test workflow pins.

The script:

1. zips `metadata.lua`, `hooks` and `lib`, and adds the zip to vfox with `vfox add maven --source`;
2. takes the newest Maven 3 and the newest Maven 4 release that `vfox search maven` lists, and two archived releases, Maven 3.0.5 and Maven 2.2.1, which only archive.apache.org has;
3. for each of the four, runs `vfox install` (which must verify the checksum), `vfox use --global`, and then `mvn --version` through `vfox env`, which must report that version.

The run has a HOME of its own, so the global selections and SDK links of the machine stay as they are.

## In CI

`.github/workflows/e2e.yml` builds the image from `tests/e2e` and runs `run.sh` in it, with the checkout mounted read-only. CI runs it on Linux amd64 only.

## Locally

With Docker:

```bash
docker build --tag vfox-maven-e2e tests/e2e
docker run --rm --volume "$PWD:/src:ro" vfox-maven-e2e bash /src/tests/e2e/run.sh
```

Or, on a host with vfox 1.1.0, zip and a Java runtime, run `bash tests/e2e/run.sh` from the repository root.

## Dev container

`.devcontainer/` describes the dev container: the tools of the lint, test and license workflows at the versions those workflows use, the vfox release of the test workflow, and a Java runtime, so `tests/e2e/run.sh` runs in it too. Open the repository with a dev container tool such as VS Code's Dev Containers, or build the image with `docker build --tag vfox-maven-dev .devcontainer`.

To run the end-to-end check in it:

```bash
docker run --rm --volume "$PWD:/src:ro" -w /src vfox-maven-dev bash tests/e2e/run.sh
```

## Known gaps

- CI runs the check on Linux amd64 only.
- Only the newest Maven 3 and Maven 4 releases and the two archived ones are installed, not every release that `vfox search` lists.
