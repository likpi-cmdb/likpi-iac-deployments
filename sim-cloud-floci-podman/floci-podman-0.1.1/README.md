# floci-podman

https://github.com/DawidAdamski/floci-podman/

Run the [Floci](https://floci.io) cloud emulators (AWS, Azure, GCP, OCI) on Podman
instead of Docker Desktop, on macOS.

> Unofficial. Not affiliated with the Floci project.

```bash
floci-podman up aws gcp     # start, then print connection details
floci-podman check          # verify containers, socket and a storage round-trip
floci-podman info --export  # bare export lines, for eval
floci-podman down --purge   # stop everything and drop the network
```

## Why

Floci officially supports Podman — the CLI honours `DOCKER_HOST`, and the docs
describe the rootless setup. But on macOS `floci start` bind-mounts the Docker
socket **without the `:z` SELinux relabel**. Inside a podman machine (Fedora
CoreOS) the container is then denied access to that socket.

The emulator still starts. S3, Blob, GCS and Object Storage all work. What breaks
is every service that spawns its own container — Lambda, Azure Functions, Cloud
Functions, ECR, EKS, CodeBuild — usually with `java.io.IOException: Broken pipe`.

`floci-podman up` runs the containers by hand with `:z` and with a named network,
because rootless Podman's default bridge gives containers no mutually routable
IPs, so a spawned function cannot reach the emulator's Runtime API.

Lowercase `z`, never `Z`. The socket is shared with the podman service, and an
exclusive relabel breaks it.

## Install

```bash
brew tap __GH_USER__/floci-podman
brew install floci-podman
```

Or clone and run `bin/floci-podman` directly — there is nothing to compile.

Requires `podman` with a running machine. The `floci` CLI itself is optional:
`logs`, `services`, `snapshot` and `env` all still work, since they talk HTTP to
the emulator rather than managing the container. Only `floci start` and
`floci stop` are replaced.

## Clouds

| Cloud | Container   | Port | Endpoint              |
|-------|-------------|------|-----------------------|
| aws   | `floci`     | 4566 | http://localhost:4566 |
| az    | `floci-az`  | 4577 | http://localhost:4577 |
| gcp   | `floci-gcp` | 4588 | http://localhost:4588 |
| oci   | `floci-oci` | 4599 | http://localhost:4599 |

Every subcommand takes a list of clouds and acts on all four when given none.
An unknown name is an error, not a silent skip.

## Connection details

`up` prints them for whatever actually came up — not for whatever you asked for.
To get them again without restarting anything:

```bash
floci-podman info gcp                       # readable
eval "$(floci-podman info aws --export)"    # straight into the shell
```

`--export` emits bare `export` lines, so it also drops into `direnv`. If you have
the `floci` CLI installed, `eval "$(floci aws env)"` is authoritative — the values
here are reconstructed from the documentation.

One detail worth knowing: `STORAGE_EMULATOR_HOST` wants a scheme, while
`PUBSUB_EMULATOR_HOST`, `FIRESTORE_EMULATOR_HOST` and `DATASTORE_EMULATOR_HOST`
want bare `host:port`. The SDKs disagree, and getting it backwards fails quietly.

## What `check` actually checks

Container running → docker socket reachable *inside* the container → health
endpoint answers → create a bucket/container, upload an object, read it back and
compare the bytes, list, clean up.

Storage is exercised over plain REST with `curl`, so you do not need `awscli` +
`azure-cli` + `gcloud` + `oci-cli` installed (about 2 GB of tooling for four HTTP
calls). None of the emulators validate credentials by default, so no request
signing is needed. Every step prints its HTTP status.

## Three traps `floci doctor` sets for you

**`docker.socket` reports a false failure.** It stats the socket path on the host,
but the socket lives inside the VM. It will always be red, and it will advise you
to open Docker Desktop. The honest test is:

```bash
podman exec floci ls -l /var/run/docker.sock   # want: srw-rw----
```

`floci-podman check` does exactly this.

**`docker.version` compares a shim against Docker Engine.** If you symlinked
`docker` to `podman`, doctor reads podman's version number and complains it is
below the 20.10 minimum. Cosmetic.

**`DOCKER_HOST` in your shell profile is a landmine.** Podman ignores it — it has
its own connection config — but the `floci` CLI, Testcontainers and `act` do not.
Pointing it at a socket that does not exist breaks those and nothing else, which
makes it hard to diagnose. `floci-podman up` warns when it sees one.

## The socket path

The bind mount uses the path as seen **from inside the VM**:

```
/run/user/<uid>/podman/podman.sock
```

The uid is detected with `podman machine ssh 'id -u'` — `0` on a rootful machine.
Override it when needed:

```bash
FLOCI_PODMAN_SOCK=/run/podman/podman.sock floci-podman up
```

If the socket is still unreachable despite `:z`, add `--security-opt label=disable`
to the `podman run` in `libexec/up.sh`.

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `FLOCI_PODMAN_SOCK` | detected | podman socket path inside the VM |
| `FLOCI_NETWORK` | `floci-net` | podman network name |
| `FLOCI_AWS_REGION` | `us-east-1` | region reported by `info` |
| `FLOCI_OCI_NAMESPACE` | `floci-local` | OCI Object Storage namespace |
| `NO_COLOR` | — | disable colored output |

## License

MIT
