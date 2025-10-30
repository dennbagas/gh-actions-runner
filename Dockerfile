FROM ghcr.io/actions/actions-runner:latest
RUN sudo apt-get update -y \
    && sudo apt-get install -y --no-install-recommends \
    # Packages in actions-runner-controller/runner-22.04
    # https://github.com/actions/actions-runner-controller/pull/2050
    # https://github.com/actions/actions-runner-controller/blob/master/runner/actions-runner.ubuntu-22.04.dockerfile
    curl \
    git \
    jq \
    unzip \
    zip \
    # Packages in actions-runner-controller/runner-20.04
    build-essential \
    locales \
    tzdata \
    # ruby/setup-ruby dependencies
    # https://github.com/ruby/setup-ruby#using-self-hosted-runners
    libyaml-dev \
    # dockerd dependencies
    iptables \
    # Remove the extra repository to reduce time of apt-get update
    && sudo add-apt-repository -r ppa:git-core/ppa \
    && sudo rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && sudo ./aws/install \
    && rm -rf aws awscliv2.zip

# Some setup actions store cache into /opt/hostedtoolcache
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN sudo mkdir /opt/hostedtoolcache \
    && sudo chown runner:docker /opt/hostedtoolcache
COPY entrypoint.sh /
VOLUME /var/lib/docker
# Disable the log by default, because it is too large
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=
# Align to GitHub-hosted runners (ubuntu-latest)
ENV LANG=C.UTF-8
ENTRYPOINT ["/usr/bin/docker-init", "-v", "--", "/entrypoint.sh"]
CMD ["/home/runner/run.sh"]
