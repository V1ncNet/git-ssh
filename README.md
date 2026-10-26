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

A tag `v<major>.<minor>.<patch>` builds the image for `linux/arm64` and pushes it to Docker Hub as `vinado/git-ssh`
with the tags `<major>`, `<major>.<minor>` and `<version>`. A weekly run rebuilds the latest release to pick up
package updates of Alpine. Every build runs `tests/smoke.sh` first.
