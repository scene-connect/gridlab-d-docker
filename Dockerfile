FROM debian:bullseye-slim AS base

ENV DEBIAN_FRONTEND="noninteractive" \
    TZ=UTC+0 \
    HELICS_INSTALL_PATH=/helics \
    GLD_INSTALL_PATH=/gridlabd \
    OPTIMISER_LEVEL=0


FROM base AS builder

# GridLAB-D required environment variables:
ENV GLPATH=${GLD_INSTALL_PATH}/lib/gridlabd:${GLD_INSTALL_PATH}/share/gridlabd \
    LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HELICS_INSTALL_PATH}/lib \
    PATH=${PATH}:${GLD_INSTALL_PATH}:${HELICS_INSTALL_PATH}

# Build dependencies.
RUN apt-get -y update \
    && apt-get -y install --no-install-recommends \
      autoconf \
      automake \
      build-essential \
      ca-certificates \
      cmake \
      default-libmysqlclient-dev \
      g++ \
      gcc \
      git \
      libboost-dev \
      libboost-chrono-dev \
      libboost-date-time-dev \
      libboost-filesystem-dev \
      libboost-program-options-dev \
      libboost-test-dev \
      libboost-timer-dev \
      libtool \
      libxerces-c3.2 \
      libxerces-c-dev \
      libzmq3-dev \
      make \
      swig

WORKDIR /build

# Build Helics, dynamically linked by GridLab-D bellow.
RUN git \
    -c advice.detachedHead=false \
    clone https://github.com/GMLC-TDC/HELICS.git \
    --branch v2.7.1 \
    --depth 1 \
    --single-branch \
    ./HELICS

WORKDIR /build/HELICS/build

RUN cmake \
      -j $(nproc) \
      -D HELICS_BUILD_CXX_SHARED_LIB=ON \
      -D CMAKE_INSTALL_PREFIX=${HELICS_INSTALL_PATH} \
      -S ../

RUN make -j $(nproc)
RUN make -j $(nproc) install

WORKDIR /build


# Build GridLab-D.
RUN git \
    -c advice.detachedHead=false \
    clone https://github.com/scene-connect/gridlab-d.git \
    --branch v4.3_mariadb \
    --depth 1 \
    --single-branch \
    ./gridlab-d

WORKDIR /build/gridlab-d

RUN autoreconf -if

RUN ./configure \
        --prefix=${GLD_INSTALL_PATH} \
        --with-mysql=/usr/lib/x86_64-linux-gnu/ \
        --with-helics=${HELICS_INSTALL_PATH} \
        --enable-silent-rules \
        "CFLAGS=-g -O${OPTIMISER_LEVEL} -w" "CXXFLAGS=-g -O${OPTIMISER_LEVEL} -w -std=c++14" "LDFLAGS=-g -O${OPTIMISER_LEVEL} -w"

RUN make MYSQL_CPPFLAGS='-I/usr/include/mysql/' --debug=v
RUN make install


# Create our runner image without all the build baggage.
FROM base AS runner

# Copy over the built paths
COPY --from=builder ${HELICS_INSTALL_PATH} /usr/local/
COPY --from=builder ${GLD_INSTALL_PATH} /usr/local/

# GridLAB-D required environment variable
ENV GLPATH=/usr/local/lib/gridlabd:/usr/local/share/gridlabd

# Run-time dependencies.
RUN apt-get -y update \
    && apt-get -y install --no-install-recommends \
        default-libmysqlclient-dev \
        libboost-dev \
        libboost-filesystem1.74.0 \
        libboost-program-options1.74.0 \
        libboost-test1.74.0 \
        libxerces-c3.2 \
        libzmq5 \
    && rm -rf /var/lib/apt/lists/*
