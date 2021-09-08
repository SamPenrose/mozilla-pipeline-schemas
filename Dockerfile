FROM centos:centos8.1.1911
LABEL maintainer="Mozilla Data Platform"

# Install the appropriate software
RUN echo 'fastestmirror=1' >> /etc/dnf/dnf.conf && \
    dnf -y update && \
    dnf -y install epel-release && \
    dnf -y install \
        cmake \
        diffutils \
        gcc \
        gcc-c++ \
        jq \
        make \
        which \
        wget \
        git \
        python36 \
        java-11-openjdk-devel \
        maven \
        cargo \
    && dnf clean all

# ensure we're actually using java 11
ENV JAVA_HOME=/etc/alternatives/java_sdk_11_openjdk
RUN alternatives --set java `readlink $JAVA_HOME`/bin/java

# Install jsonschema-transpiler
ENV PATH=$PATH:/root/.cargo/bin
RUN cargo install jsonschema-transpiler --version 1.9.0

# Configure git for testing
RUN git config --global user.email "mozilla-pipeline-schemas@mozilla.com"
RUN git config --global user.name "Mozilla Pipeline Schemas"

WORKDIR /app

COPY --from=mozilla/ingestion-sink:latest /app/ingestion-sink/target /app/target

# Install python dependencies
COPY requirements.txt requirements-dev.txt ./
RUN pip3 install --upgrade pip setuptools && \
    pip3 install -r requirements.txt -r requirements-dev.txt

# Install Java dependencies
COPY pom.xml .
RUN mvn dependency:copy-dependencies

COPY . /app

RUN pip3 install .
RUN mkdir release && \
    cd release && \
    cmake .. && \
    make

CMD pytest -v
