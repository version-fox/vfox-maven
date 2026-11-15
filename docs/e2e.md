# End-to-end check and dev container

[中文](zh-CN/e2e.md) | [English](e2e.md)

The offline tests cannot tell whether vfox installs a real Maven, so the end-to-end check does that. It is a Go test in `tests/e2e`: it runs real vfox against Apache's real archives.

## What it checks

For the newest Maven 4 and Maven 3 releases that `vfox search maven` lists, and for three archived releases, Maven 3.0.5, Maven 2.2.1 and Maven 1.1:

1. `vfox add maven --source` adds the plugin, packed from the checkout (`metadata.lua`, `hooks` and `lib`), and `vfox search maven` lists the archived releases;
2. `vfox install` installs the release, and its output shows that vfox verified the checksum;
3. `vfox use --global` selects the release: in a shell with vfox activated, the Maven command (`mvn`, or `maven` for Maven 1) resolves to the release, reports it, and runs it;
4. the EnvKeys hook of the plugin, run through `vfox plugin run`, puts the bin directory of the release on `PATH`.

Three scenarios then check the other scopes of `vfox use`:

- a release selected for the session (`vfox use`) wins over the global selection, and the session ends with its shell;
- `vfox use --project` selects a release for a project directory, in its `.vfox.toml`, and the global selection still applies outside that directory;
- `vfox use` with a major version alone (`maven@3`) selects the newest installed release of that major version.

`vfox use` takes effect only in a shell that has vfox activated, as a user's shell has it, so the scenarios run in one: bash on Linux and macOS, and PowerShell 7 on Windows. The script runs `vfox activate`, then `vfox use`, then `vfox env`, because a script does not run the prompt hook that applies `vfox env`, and then the Maven command. `VFOX_MAVEN_SHELL` (`bash` or `pwsh`) overrides the choice, so the PowerShell path can run on Linux. The variables of a vfox session (`__VFOX_*`) are removed from the environment of these shells, so a session of the shell that starts the check is not inherited.

The run has a HOME of its own (`HOME` and `USERPROFILE` both point at a temporary directory), so the vfox caches and selections of the machine stay as they are.

## What it needs

- vfox 1.1.0 on `PATH`.
- A Java runtime for Maven 2 to 4: the default JDK.
- `VFOX_MAVEN_JAVA8_HOME`: a JDK 8 with `lib/tools.jar`, for Maven 1.1. Its launcher passes `-Djava.endorsed.dirs`, which JDK 9 and later refuse, so Maven 1 runs on JDK 8 only.
- bash on Linux and macOS, and PowerShell 7 (`pwsh`) on Windows.
- The network, for Apache's servers.

`VFOX_MAVEN_PLUGIN_DIR` names the checkout of the plugin. It defaults to the repository that holds the test.

## Running it

From `tests/e2e`:

```bash
go test -v -run '^TestE2E$' -timeout 40m .
```

The unit tests need no network, and `-short` runs only them:

```bash
go test -short ./...
```

## In CI

- `e2e.yml`, Linux: the check is built for the runner's architecture with `go test -c`, and runs in the e2e image (`tests/e2e/Dockerfile`), with the checkout mounted read-only. The runners are `ubuntu-latest` (amd64) and `ubuntu-26.04-arm` (arm64).
- `e2e.yml`, Windows: the check runs natively on `windows-latest`, in PowerShell 7. `setup-java` installs a JDK 8 for Maven 1.1 and a JDK 21 as the default.
- `lint.yml`: `gofmt`, `go vet` and `go test -short` on the Go code.

## Dev container

`.devcontainer/` describes the dev container: the tools of the lint, test and license workflows at the versions those workflows use, the vfox release of the test workflow, a Java runtime, and a JDK 8 for Maven 1.1. Open the repository with a dev container tool such as VS Code's Dev Containers, or build the image with `docker build --tag vfox-maven-dev .devcontainer`.

To run the check in it, from the source:

```bash
docker run --rm --volume "$PWD:/src:ro" --env VFOX_MAVEN_PLUGIN_DIR=/src -w /src/tests/e2e vfox-maven-dev go test -count=1 -v -run '^TestE2E$' -timeout 40m .
```

To run the check in the e2e image on a Linux host, build the test binary for the host and mount it:

```bash
(cd tests/e2e && CGO_ENABLED=0 go test -c -o /tmp/e2e.test .)
docker build --tag vfox-maven-e2e tests/e2e
docker run --rm --volume "$PWD:/src:ro" --volume /tmp/e2e.test:/usr/local/bin/e2e.test:ro --env VFOX_MAVEN_PLUGIN_DIR=/src vfox-maven-e2e e2e.test -test.run '^TestE2E$' -test.v -test.timeout 40m
```

## Known gaps

- The check installs the newest Maven 3 and Maven 4 releases and the three archived ones, not every release that `vfox search` lists.
- The scenarios use the default `PreUse` of the plugin, which does nothing: the matching of versions is vfox's.
