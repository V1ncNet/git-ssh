#!/usr/bin/env bash
# Runs the image like the pod does and checks the Git workflow over SSH.
set -euo pipefail

image=${1:?usage: smoke.sh <image>}
port=${SMOKE_PORT:-22222}
work=$(mktemp -d)
container=git-ssh-smoke-$$

cleanup() {
    status=$?
    [ "$status" -eq 0 ] || docker logs "$container" 2>&1 | tail -20
    docker rm -f "$container" >/dev/null 2>&1 || true
    rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/keys" "$work/authorized_keys"
for type in ecdsa ed25519 rsa; do
    ssh-keygen -q -t "$type" -N '' -f "$work/keys/ssh_host_${type}_key"
done
ssh-keygen -q -t ed25519 -N '' -f "$work/id"
cp "$work/id.pub" "$work/authorized_keys/git"
chmod 0600 "$work/keys/"*_key
chmod 0644 "$work/authorized_keys/git"

docker run -d --name "$container" --read-only --tmpfs /tmp --tmpfs /home/git:uid=1001,gid=1001 \
    --cap-drop ALL --security-opt no-new-privileges -p "127.0.0.1:$port:2222" \
    -v "$work/keys:/etc/ssh/keys:ro" -v "$work/authorized_keys:/etc/ssh/authorized_keys:ro" "$image" >/dev/null

ssh_opts=(-p "$port" -i "$work/id" -o IdentitiesOnly=yes -o BatchMode=yes -o UserKnownHostsFile="$work/known_hosts"
    -o StrictHostKeyChecking=accept-new)
for _ in $(seq 30); do
    ssh "${ssh_opts[@]}" git@127.0.0.1 true 2>/dev/null && break
    sleep 1
done

remote() { ssh "${ssh_opts[@]}" git@127.0.0.1 "$@"; }
remote 'mkdir -p vinado && git init -q --bare vinado/x.git && mv vinado/x.git vinado/y.git'
[ "$(remote 'ls vinado')" = y.git ] || { echo "FAIL: create and move"; exit 1; }
[ "$(remote 'git -C vinado/y.git symbolic-ref HEAD')" = refs/heads/main ] || { echo "FAIL: default branch"; exit 1; }

export GIT_SSH_COMMAND="ssh ${ssh_opts[*]}"
git -c init.defaultBranch=main init -q "$work/repo"
git -C "$work/repo" -c user.name=Smoke -c user.email=smoke@example.invalid commit -q --allow-empty -m Smoke
git -C "$work/repo" push -q git@127.0.0.1:vinado/y.git main
git clone -q git@127.0.0.1:vinado/y.git "$work/clone"
[ "$(git -C "$work/clone" log --format=%s)" = Smoke ] || { echo "FAIL: push and clone"; exit 1; }

printf 'echo interactive\nexit\n' | remote -tt >/dev/null 2>&1 || true
remote 'rm -rf vinado'
[ -z "$(remote 'ls -A')" ] || { echo "FAIL: home not empty: $(remote 'ls -A')"; exit 1; }

effective=$(docker exec "$container" /usr/sbin/sshd -T -f /etc/ssh/sshd_config)
for setting in "persourcepenalties no" "allowtcpforwarding no" "allowagentforwarding no" "x11forwarding no" \
    "passwordauthentication no" "permittunnel no"; do
    grep -qx "$setting" <<<"$effective" || { echo "FAIL: $setting"; exit 1; }
done

echo PASS
