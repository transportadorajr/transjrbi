# Imagem de DESENVOLVIMENTO (Docker Compose + Dev Container).
# O Dockerfile da raiz do projeto é o de produção gerado pelo Rails.

# Mantenha alinhado com .ruby-version
ARG RUBY_VERSION=4.0.7
ARG BUN_VERSION=1.4.2

FROM oven/bun:${BUN_VERSION} AS bun

FROM docker.io/library/ruby:${RUBY_VERSION}

# Pacotes do sistema: cliente/headers do PostgreSQL, libvips (Active Storage), utilitários
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential git curl sudo less vim \
      libpq-dev postgresql-client libvips libyaml-dev && \
    rm -rf /var/lib/apt/lists/*

# Bun (gerenciador de pacotes e bundler de JavaScript)
COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun
RUN ln -s /usr/local/bin/bun /usr/local/bin/bunx

# Usuário não-root (evita arquivos com dono root na pasta do projeto)
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME} && \
    mkdir -p /usr/local/bundle && chown -R ${USERNAME}:${USERNAME} /usr/local/bundle

ENV BUNDLE_PATH=/usr/local/bundle \
    BINDING=0.0.0.0 \
    EDITOR=vim

USER ${USERNAME}
WORKDIR /workspaces/transjrbi
