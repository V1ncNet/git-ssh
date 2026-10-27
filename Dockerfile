FROM --platform=$BUILDPLATFORM golang:1.27.2-alpine@sha256:f92b6ef800e499660581efdabdf25d9d817a9d124eaf900924f0504e7e27e12d AS lfs
ARG TARGETARCH
WORKDIR /src
COPY tools/go.mod tools/go.sum ./
RUN go mod download
RUN CGO_ENABLED=0 GOARCH=$TARGETARCH go build -trimpath -ldflags=-s -o /out/git-lfs-transfer \
    github.com/charmbracelet/git-lfs-transfer

FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

RUN apk add --no-cache bash git openssh-server \
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
