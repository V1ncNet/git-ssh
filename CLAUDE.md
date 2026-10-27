# CLAUDE.md

Guidance for coding agents working in this repository. The README covers what the image is and how to use it.

## Layout

| Path | Purpose |
|-|-|
| `Dockerfile` | Stage `lfs` compiles `git-lfs-transfer`. The final stage is Alpine with `bash`, `git` and `openssh-server` |
| `sshd_config` | Public key login for `git` only, no forwarding, `MaxStartups 20:30:60`, `PerSourcePenalties no` |
| `gitconfig` | System Git config, sets `init.defaultBranch main` |
| `profile.sh` | Installed as `/etc/profile.d/no-history.sh`, unsets `HISTFILE` |
| `git-lfs-transfer.sh` | Installed as `/usr/local/bin/git-lfs-transfer`, wraps the binary in `/usr/local/libexec` |
| `tools/go.mod`, `tools/go.sum` | Pin `github.com/charmbracelet/git-lfs-transfer` through a `tool` directive |
| `tests/smoke.sh` | Starts the image like the pod does and checks the Git and LFS workflow over SSH |
| `.github/workflows/deploy.yml` | Smoke test, release and push to Docker Hub, zizmor and dependency review on pull requests |
| `.github/workflows/scan.yml` | Daily Trivy scan of `vinado/git-ssh:1` |
| `.github/dependabot.yml` | Weekly updates of Docker, Go modules and actions with seven days of cooldown, grouped into one pull request per ecosystem, because every merge to `main` releases |

## Testing locally

```sh
docker build --platform linux/arm64 -t git-ssh:test .
nix shell nixpkgs#git-lfs --command tests/smoke.sh git-ssh:test
nix shell nixpkgs#zizmor --command zizmor .github/workflows/
```

The image exists for `linux/arm64` only. `smoke.sh` needs `git-lfs` on the host and listens on port `22222`, override
it with `SMOKE_PORT`. Fetch missing tools ad hoc with `nix shell nixpkgs#<tool>`.

A change to a value in `sshd_config` needs the matching entry in the `sshd -T` assertion list at the end of
`tests/smoke.sh`.

## Runtime constraints

- The container runs as UID and GID `1001` with a read-only root filesystem and no capabilities.
- `sshd` listens on port `2222`. Mounts are `/etc/ssh/keys` (host keys), `/etc/ssh/authorized_keys/git`, `/home/git`
  (repositories) and `/tmp`.
- Configuration never lives on the repositories volume. Anything the image needs belongs in the image or a read-only
  mount.

## Why things are as they are

- `git-lfs-transfer.sh` exists because `git-lfs-transfer` does not append `.git` to a repository path the way
  `git-upload-pack` does. Clients that clone `team/y` would otherwise fail on LFS requests. It also resolves a
  leading `~` to `$HOME`, because Git accepts remotes like `ssh://host/~/repo.git` and git-lfs passes that path on
  literally.
- `MaxStartups 20:30:60` keeps `sshd` from dropping connections at random below the proxy limit. A TCP proxy in front
  limits concurrent connections per address to ten, and LFS opens several at once.
- `PerSourcePenalties no`, because the image sits behind a proxy that hides client addresses. Rate limiting belongs to
  the proxy.
- The `lfs` stage runs on `$BUILDPLATFORM` and cross-compiles for `$TARGETARCH`, so CI does not
  compile Go under QEMU. The final stage still runs `apk add` under QEMU. Modules download in their own layer.
- The `tool` directive keeps `go mod tidy` from removing the dependency, which no Go file imports. Go marks it
  `// indirect`, and Dependabot ignores indirect dependencies by default, so the `gomod` entry sets
  `allow: dependency-type: all`.

## Releases

- Every push to `main` releases the next patch version. The label `release:minor` or `release:major` on the merged
  pull request raises that part and resets the lower ones to 0.
- Pushes that only touch `README.md`, `.github/workflows/scan.yml` or `.github/dependabot.yml` do not release (the
  `paths-ignore` of `deploy.yml`). Every other push to `main` does, including pushes that only touch `CLAUDE.md` or
  `tests/`.
- `deploy.yml` looks up the pull request of the pushed commit and retries up to five times while GitHub has not linked
  it yet. An API error fails the step. Without a pull request the release is a patch.
- The workflow pushes `vinado/git-ssh` with the tags `<major>`, `<major>.<minor>` and `<version>`, then tags the commit
  `v<version>`.
- `scan.yml` fails on fixable high or critical findings and starts `deploy.yml` by `workflow_dispatch`, which rebuilds
  the latest tag with fixed Alpine packages. A scan error fails the run without a rebuild. The `follow-up` job
  re-enables `scan.yml` on every run, so GitHub does not disable it after 60 days without commits. It needs
  `actions: write` for that.

## Conventions

- Commit messages follow the seven rules by Chris Beams and are written in English.
- Workflows pin actions to a commit with the version in a trailing comment and must pass zizmor. Values reach `run:`
  through `env:`, never through `${{ }}`.
- Images are pinned by tag and digest in the `Dockerfile`.
