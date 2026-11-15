# Copyright 2026 Han Li and contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The repository dev container (see docs/e2e.md): the tools that the lint, test
# and license workflows run, the vfox release they test with, and a Java runtime for
# the end-to-end check, which is a Go test in tests/e2e. Its versions match those
# workflows and the e2e image in tests/e2e/Dockerfile; change them together.
#
# Each download picks its asset by the architecture.

FROM golang:1.27.1

# Keep these in step with .github/workflows/lint.yml (the stylua-action version
# and the LuaLS version of its mise line), with test.yml (vfox) and with
# tests/e2e/Dockerfile (vfox).
ARG STYLUA_VERSION=2.5.2
ARG LUA_LANGUAGE_SERVER_VERSION=3.19.1
ARG VFOX_VERSION=1.1.0

RUN set -o errexit -o nounset -o xtrace; \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        ca-certificates \
        curl \
        default-jre-headless \
        git \
        unzip \
        zip; \
    rm --recursive --force /var/lib/apt/lists/*; \
    case "$(dpkg --print-architecture)" in \
        amd64) stylua_asset=stylua-linux-x86_64.zip; luals_asset="lua-language-server-${LUA_LANGUAGE_SERVER_VERSION}-linux-x64.tar.gz"; vfox_dir="vfox_${VFOX_VERSION}_linux_x86_64" ;; \
        arm64) stylua_asset=stylua-linux-aarch64.zip; luals_asset="lua-language-server-${LUA_LANGUAGE_SERVER_VERSION}-linux-arm64.tar.gz"; vfox_dir="vfox_${VFOX_VERSION}_linux_aarch64" ;; \
        *) echo "unsupported architecture" >&2; exit 1 ;; \
    esac; \
    curl --fail --silent --show-error --location --output /tmp/stylua.zip \
        "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/${stylua_asset}"; \
    unzip -q /tmp/stylua.zip -d /usr/local/bin; \
    rm --force /tmp/stylua.zip; \
    mkdir --parents /opt/lua-language-server; \
    curl --fail --silent --show-error --location --output /tmp/luals.tar.gz \
        "https://github.com/LuaLS/lua-language-server/releases/download/${LUA_LANGUAGE_SERVER_VERSION}/${luals_asset}"; \
    tar --extract --gzip --file /tmp/luals.tar.gz --directory /opt/lua-language-server; \
    rm --force /tmp/luals.tar.gz; \
    ln --symbolic /opt/lua-language-server/bin/lua-language-server /usr/local/bin/lua-language-server; \
    curl --fail --silent --show-error --location --output /tmp/vfox.tar.gz \
        "https://github.com/version-fox/vfox/releases/download/v${VFOX_VERSION}/${vfox_dir}.tar.gz"; \
    tar --extract --gzip --file /tmp/vfox.tar.gz --directory /usr/local/bin --strip-components=1 "${vfox_dir}/vfox"; \
    rm --force /tmp/vfox.tar.gz; \
    GOBIN=/usr/local/bin go install github.com/apache/skywalking-eyes/cmd/license-eye@v0.9.0; \
    stylua --version; \
    lua-language-server --version; \
    vfox --version; \
    command -v license-eye

# A JDK 8 for Maven 1.1, next to the default runtime above: its launcher needs a JDK
# with lib/tools.jar, and the end-to-end check (see docs/e2e.md) reads its path from
# VFOX_MAVEN_JAVA8_HOME. Debian has no JDK 8 package, so the JDK comes from the Temurin
# release of the architecture, checked against the checksum pinned for it.
ARG TEMURIN8_RELEASE=jdk8u512-b09
ARG TEMURIN8_VERSION=8u512b09
ARG TEMURIN8_X64_SHA256=fb3bfa869012419b562bb4235d0d83ec4f8c1dda62ae432ba20c6c3a7e43f7e4
ARG TEMURIN8_AARCH64_SHA256=01263df22c4553f63146bbae807e70cd4628dd0d9ec7582f01cb2453f7c69aaa

RUN set -o errexit -o nounset -o xtrace; \
    case "$(dpkg --print-architecture)" in \
        amd64) jdk_arch=x64; jdk_sha256="${TEMURIN8_X64_SHA256}" ;; \
        arm64) jdk_arch=aarch64; jdk_sha256="${TEMURIN8_AARCH64_SHA256}" ;; \
        *) echo "unsupported architecture" >&2; exit 1 ;; \
    esac; \
    jdk_asset="OpenJDK8U-jdk_${jdk_arch}_linux_hotspot_${TEMURIN8_VERSION}.tar.gz"; \
    curl --fail --silent --show-error --location --output /tmp/jdk8.tar.gz \
        "https://github.com/adoptium/temurin8-binaries/releases/download/${TEMURIN8_RELEASE}/${jdk_asset}"; \
    echo "${jdk_sha256}  /tmp/jdk8.tar.gz" | sha256sum --check; \
    mkdir --parents /opt/jdk8; \
    tar --extract --gzip --file /tmp/jdk8.tar.gz --directory /opt/jdk8 --strip-components=1; \
    rm --force /tmp/jdk8.tar.gz; \
    test -f /opt/jdk8/lib/tools.jar

ENV VFOX_MAVEN_JAVA8_HOME=/opt/jdk8
