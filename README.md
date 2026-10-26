# git-ssh

A plain SSH server for bare Git repositories, packaged as a container image. It also serves Git LFS over SSH, so large
files need no separate HTTP endpoint. Repositories are created, moved and removed with `git init --bare`, `mv` and `rm`
in a regular Bash session.

## Running

The image runs `sshd` on port `2222` as the unprivileged user `git` (UID and GID `1001`) with a read-only root
filesystem. It accepts public keys only and allows no forwarding.

| Path | Content |
|-|-|
| `/etc/ssh/keys/ssh_host_{ecdsa,ed25519,rsa}_key` | Host keys. Either owned by root and group-readable, or owned by `1001` with mode `0600` |
| `/etc/ssh/authorized_keys/git` | Public keys allowed to log in as `git` |
| `/home/git` | Repositories, writable by `1001` |
| `/tmp` | Writable scratch space |

## Using it

Create a repository on the server, then clone and push as with any other remote:

```sh
ssh -p 2222 git@example.org 'git init --bare project.git'
git clone ssh://git@example.org:2222/~/project.git
```

Git LFS works without further setup, given a client with `git-lfs` 3.6 or newer. Run `git lfs install` once and track
files as usual.

## Releases

Every merge to `main` builds and publishes the next patch version as `vinado/git-ssh` for `linux/arm64`. A
`release:minor` or `release:major` label on the pull request raises that part of the version instead.

The published image is scanned for known vulnerabilities and kept up to date automatically.
