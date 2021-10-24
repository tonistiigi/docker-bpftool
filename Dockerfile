#syntax=docker/dockerfile:1.3-labs

FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.0.0@sha256:494fa8488689d499edfaa16dba5922bc2b8cdfcb220bf884354aecbc1f2d8996 AS xx

FROM --platform=$BUILDPLATFORM alpine AS linux-src
WORKDIR /src
ARG LINUX_VERSION=5.14.14
RUN wget -O - https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${LINUX_VERSION}.tar.xz | tar xJf - --strip-components=1

FROM --platform=$BUILDPLATFORM alpine AS base
RUN apk add git clang lld make llvm
COPY --from=xx / /

FROM base AS musl
ARG MUSL_VERSION=v1.2.2
WORKDIR /src
COPY ftw_subtree.patch .
RUN <<eot
	set -ex
	git clone https://github.com/ifduyue/musl.git
	cd musl
	git checkout $MUSL_VERSION
	git apply ../ftw_subtree.patch
eot
ARG TARGETPLATFORM
RUN xx-apk add musl-dev gcc
WORKDIR musl
RUN <<eot
	set -ex
	CC=xx-clang ./configure --prefix=/opt/musl --host=$(xx-clang --print-target-triple)
	make -j$(nproc)
	make install
	make clean
eot

FROM base AS build
RUN apk add python3 binutils
ARG BUILD_DEPS="zlib-dev zlib-static linux-headers elfutils-dev libelf-static musl-dev gcc"
RUN apk add ${BUILD_DEPS} # builder will always bootstrap native target first so double libraries are needed
ARG TARGETPLATFORM
RUN xx-apk add ${BUILD_DEPS}
WORKDIR /src
ARG CFLAGS="-Wl,-s -Os"
RUN --mount=target=/opt/musl,from=musl,src=/opt/musl \
	--mount=target=.,from=linux-src,src=/src,rw <<eot
	set -ex
	cp -a /opt/musl/. $(xx-info sysroot)/usr/
	cd tools/bpf/bpftool
	xx-clang --setup-target-triple
	export CFLAGS="${CFLAGS} --static"
	make CC=xx-clang HOSTCC=clang LD=ld.lld AR=llvm-ar
	xx-verify --static ./bpftool
	mkdir /out
	mv ./bpftool /out
	make clean
eot

FROM scratch
COPY --from=build /out/ /
ENTRYPOINT [ "/bpftool" ]