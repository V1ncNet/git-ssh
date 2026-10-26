FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

RUN apk add --no-cache bash git openssh-server \
    && addgroup -g 1001 git \
    && adduser -D -u 1001 -G git -h /home/git -s /bin/bash git \
    && sed -i 's/^git:!/git:*/' /etc/shadow

COPY sshd_config /etc/ssh/sshd_config
COPY gitconfig /etc/gitconfig
COPY profile.sh /etc/profile.d/no-history.sh

USER 1001
EXPOSE 2222
CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/etc/ssh/sshd_config"]
