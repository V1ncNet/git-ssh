FROM --platform=$BUILDPLATFORM golang:1.27.3-alpine@sha256:fa3d596898d9f126af7c01d14ee7597bab3f39cccf392ef36b69fe77cd681f18 AS lfs
ARG TARGETARCH
WORKDIR /src
COPY tools/go.mod tools/go.sum ./
RUN go mod download
RUN CGO_ENABLED=0 GOARCH=$TARGETARCH go build -trimpath -ldflags=-s -o /out/git-lfs-transfer \
    github.com/charmbracelet/git-lfs-transfer

FROM alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

RUN apk upgrade --no-cache \
    && apk add --no-cache bash git openssh-server \
    && addgroup -g 1001 git \
    && adduser -D -u 1001 -G git -h /home/git -s /bin/bash git \
    && sed -i 's/^git:!/git:*/' /etc/shadow

COPY --from=lfs /out/git-lfs-transfer /usr/local/libexec/git-lfs-transfer
COPY git-lfs-transfer.sh /usr/local/bin/git-lfs-transfer
COPY sshd_config /etc/ssh/sshd_config
COPY gitconfig /etc/gitconfig
COPY profile.sh /etc/profile.d/no-history.sh

USER 1001
EXPOSE 2222
CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/etc/ssh/sshd_config"]
