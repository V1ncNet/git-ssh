# git-ssh

Container image that serves bare Git repositories over SSH. It runs as the unprivileged user `git` (UID and GID
`1001`) with a read-only root filesystem. The user keeps a regular Bash, so repositories are created, moved and
removed with `git init --bare`, `mv` and `rm`.

## Mounts

| Path | Content |
|-|-|
| `/etc/ssh/keys/ssh_host_{ecdsa,ed25519,rsa}_key` | Host keys. Either owned by root and group-readable, or owned by `1001` with mode `0600` |
| `/etc/ssh/authorized_keys/git` | Public keys allowed to log in as `git` |
| `/home/git` | Repositories, writable by `1001` |
| `/tmp` | Writable scratch space |

`sshd` listens on port `2222`. It accepts public keys only and allows no forwarding. `PerSourcePenalties` is off,
because the image is meant to sit behind a proxy that hides client addresses. Rate limiting belongs to that proxy.

## Releases

Every push to `main` releases the next patch version. The workflow builds the image for `linux/arm64`, pushes it to
Docker Hub as `vinado/git-ssh` with the tags `<major>`, `<major>.<minor>` and `<version>` and then tags the commit
`v<version>`. A merged Dependabot pull request therefore ships without further steps. Changes to this README alone do
not release, neither do changes to the scan workflow or the Dependabot configuration. Every build runs
`tests/smoke.sh` first.

## Vulnerability scan

A daily run scans `vinado/git-ssh:1` with Trivy for high and critical vulnerabilities that already have a fix. A
finding fails the run, so GitHub sends a mail, and starts a rebuild of the latest release with the fixed Alpine
packages. Renovate in the consuming repository then proposes the new digest. Unfixed vulnerabilities do not fail the
run. A scan error fails the run as well, but starts no rebuild. The image exists for `linux/arm64` only, so the scan
sets `TRIVY_PLATFORM`.

The scan job runs without secrets and with read access only. The Trivy action is pinned to a commit, because its
version tags were hijacked in March 2026 (CVE-2026-33634). A second job holds `actions: write` to start the rebuild
and to re-enable the scan workflow on every run, so GitHub does not disable it after 60 days without commits.

Dependabot updates the base image and the actions weekly with a cooldown of seven days against supply chain attacks.
Security fixes do not wait for it, they arrive through the rebuild above.
