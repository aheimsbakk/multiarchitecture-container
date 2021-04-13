#!/bin/sh

# convert docker architecture to qemu architecture
get_arch2arch() {
  arch="$1"

  case "$arch" in
    amd64) echo amd64 ;;
    arm64v8) echo aarch64 ;;
    arm32v7) echo arm ;;
    arm32v6) echo arm ;;
    *) exit 1;;
  esac
}

# get qemu container for architecture
get_multiarch_qemu_container() {
  arch="$(get_arch2arch "$1")"

  [ "$arch" != "amd64" ] &&
    echo "FROM docker.io/multiarch/qemu-user-static:x86_64-$arch as qemu"
}

# get the content of the dockerfile
get_dockerfile() {
  arch="$1"; shift
  dockerfile="$1"

  if [ "$arch" != "amd64" ]
  then
    sed "s#docker.io/#docker.io/$arch/#g" "$dockerfile" |
      sed "/^FROM /a COPY --from=qemu /usr/bin/qemu-$(get_arch2arch "$arch")-static /usr/bin" |
      sed "0,/FROM /!b;//i $(get_multiarch_qemu_container "$arch")\n"
  else
    cat "$dockerfile"
  fi
}

### main

BASEDIR="$(dirname "$0")"
ARCHITECTURES="$(cat "$BASEDIR"/build.arch)"
DOCKERFILE_PATH="$1"
IMAGE_NAME="$2"

# print help
if [ -z "$DOCKERFILE_PATH" ] || [ -z "$IMAGE_NAME" ]
then
  echo "$(basename "$0")" DOCKERFILE_PATH IMAGE_NAME
  exit 1
fi

if which podman > /dev/null 2>&1
then
  DOCKER_CMD=podman
else
  DOCKER_CMD=docker
fi

# turn on multiarch for local build
[ "$DOCKER_CMD" = "podman" ] && sudo hooks/pre_build

# build for all architectures
for arch in $ARCHITECTURES
do
  echo
  echo %%
  echo %% BUILDING FOR ARCHITECTURE = "$arch" =
  echo %%
  echo

  get_dockerfile "$arch" "$DOCKERFILE_PATH/Dockerfile"  |
    $DOCKER_CMD build --tag "$IMAGE_NAME-$arch" --file -
done
