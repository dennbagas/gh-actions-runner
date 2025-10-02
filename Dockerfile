# =============================
# Stage 1: Build environment
# =============================
FROM ubuntu:24.04 AS build

ARG RUNNER_VERSION=2.328.0
ARG RUNNER_ARCH=x64
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.7.0
ARG DUMB_INIT_VERSION=1.2.5
ARG ARCH=x86_64

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    buildah \
    ca-certificates \
    curl \
    git \
    jq \
    unzip \
    python3 \
    python3-pip \
    xz-utils \
    zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Runner user
RUN adduser --disabled-password --gecos "" --uid 1001 runner

# Make and set the working directory
RUN mkdir -p /home/runner \
  && chown -R $USERNAME:$GID /home/runner

WORKDIR /home/runner

# Install dumb-init
RUN curl -f -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} \
    && chmod +x /usr/local/bin/dumb-init

# Install GitHub Actions Runner
RUN curl -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
  && tar xzf ./runner.tar.gz \
  && rm runner.tar.gz \
  && ./bin/installdependencies.sh \
  && apt-get autoclean \
  && rm -rf /var/lib/apt/lists/*

# Install container hooks (needed in Kubernetes)
RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

    # Make the rootless runner directory and externals directory executable
RUN mkdir -p /run/user/1001 \
  && chown runner:runner /run/user/1001 \
  && chmod a+x /run/user/1001 \
  && mkdir -p /home/runner/externals \
  && chown runner:runner /home/runner/externals \
  && chmod a+x /home/runner/externals

# =============================
# Stage 2: Final minimal image
# =============================
FROM scratch AS final

# Set environment variables needed at build or run
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

# Add the Python "User Script Directory" to the PATH
ENV HOME=/home/runner
ENV PATH="${PATH}:${HOME}/.local/bin:/home/runner/bin"
ENV ImageOS=ubuntu24

# No group definition, as that makes it harder to run docker.
USER runner

# Squashing time ...
COPY --from=build / /

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
