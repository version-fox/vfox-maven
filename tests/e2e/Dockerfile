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

# The image of the end-to-end check (see docs/e2e.md): Ubuntu, the Java runtimes that
# Maven needs, and the vfox release that the test workflow pins. The check is a Go test
# binary, which the workflow builds for the runner's architecture and mounts here; the
# plugin is mounted from the checkout too, so neither is copied into the image.
#
# The Java runtimes come from apt, not from vfox: Maven needs one to run, and this
# plugin does not install a JDK. Maven 1 also needs a JDK 8 with lib/tools.jar, so the
# JDK rather than the JRE, and VFOX_MAVEN_JAVA8_HOME names it.

FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

# Keep in step with .github/workflows/test.yml.
ARG VFOX_VERSION=1.1.0

RUN set -o errexit -o nounset -o xtrace; \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        ca-certificates \
        curl \
        default-jre-headless \
        openjdk-8-jdk-headless; \
    rm --recursive --force /var/lib/apt/lists/*; \
    jdk8="$(ls --directory /usr/lib/jvm/java-8-openjdk-*)"; \
    test -f "${jdk8}/lib/tools.jar"; \
    ln --symbolic "${jdk8}" /opt/jdk8; \
    case "$(dpkg --print-architecture)" in \
        amd64) vfox_dir="vfox_${VFOX_VERSION}_linux_x86_64" ;; \
        arm64) vfox_dir="vfox_${VFOX_VERSION}_linux_aarch64" ;; \
        *) echo "unsupported architecture" >&2; exit 1 ;; \
    esac; \
    curl --fail --silent --show-error --location --output /tmp/vfox.tar.gz \
        "https://github.com/version-fox/vfox/releases/download/v${VFOX_VERSION}/${vfox_dir}.tar.gz"; \
    tar --extract --gzip --file /tmp/vfox.tar.gz --directory /usr/local/bin --strip-components=1 "${vfox_dir}/vfox"; \
    rm --force /tmp/vfox.tar.gz; \
    vfox --version

ENV VFOX_MAVEN_JAVA8_HOME=/opt/jdk8
