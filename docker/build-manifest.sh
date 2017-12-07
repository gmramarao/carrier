#!/bin/sh

# /!\ DO NOT EDIT THIS FILE
# It is part of the automated build system. If you want to customize your image
# you can modify its manifest file located in the `context` directory

set -e

checkArguments() {
  local argument_error_message="$(
  cat << EOI
OK, you gave me some baadf00d. I only expect one argument, and this argument
must be a valid file path of a manifest file for a project that build a sexy
chicky big mama of docker image that is so fancy and so shiny it'll make you
happy for the rest of your life...unless you gave me some baadf00d like now...
Bye.
EOI
  )"
  
  # This script needs one argument: a path to a manifest file
  if [ ! $# -eq 1 ]; then
    echo "$argument_error_message" 1>&2
    exit 1
  fi
  
  if [ ! -f "$1" ];then
    echo "$argument_error_message" 1>&2
    exit 1
  fi
}

checkFoundationImages() {
  # first, verify if bootstrap has built all necessary foundation images, that
  # is metabarj0/manifest, metabarj0/gcc, metabarj0/make and
  # metabarj0/docker-cli
  local required_images="$(
  cat << EOI
metabarj0/manifest
metabarj0/gcc
metabarj0/make
metabarj0/docker-cli
EOI
  )"
  
  for i in $required_images; do
    id=$(docker image ls -q $i)
    if [ -z $id ]; then
      echo 'Hmm...the mandatory image '$i' has not been found on your' 1>&2
      echo 'docker host...That is annoying! Make sure you have built and' 1>&2
      echo 'run the bootstrap project before attempting to build any' 1>&2
      echo 'further project. Bootstrap is the only one who need to be' 1>&2
      echo 'built by hand.' 1>&2
      exit 1
    fi
  done
}

increaseRecursiveLevel() {
  # does work even if the var is not set first
  export RECURSIVE_LEVEL=$(( RECURSIVE_LEVEL + 1 ))
}

decreaseRecursiveLevel() {
  # unset the var once 0 is reached
  export RECURSIVE_LEVEL=$(( RECURSIVE_LEVEL - 1 ))
  if [ $RECURSIVE_LEVEL -eq 0 ]; then
    unset RECURSIVE_LEVEL
  fi
}

buildDependencies() {
  # any dependency build will increase the recursive level
  increaseRecursiveLevel

  # browse all dependencies
  for dep in $REQUIRES; do
    # first, check on the host if the image exists; if so, continue without
    # building it
    local repository=$(docker image ls -q "$dep")
    if [ ! -z "$repository" ]; then
      continue
    fi

    # no existing image found on the host, building it
    local dependency_manifest=$(
      find $BUILD_TOOLS_DIRECTORY \
        -name manifest \
        -exec \
          grep -EH 'PROVIDES='$dep {} \; \
          | sed -r 's/^([^:]+):.+/\1/'
    )

    # about to trigger a recursive build in a subshell
    ( exec $0 "$dependency_manifest" )
  done

  # dependecies build done, decrese the recursive level, unsetting it if 0
  decreaseRecursiveLevel
}

setupDirectories() {
  # extract useful directory paths
  local user_directory=$(pwd -P)

  # extract the build tools directory and expose it as global
  cd $(dirname $0)
  local this_directory=$(pwd -P)
  BUILD_TOOLS_DIRECTORY=${this_directory}/build-tools

  # extract the project directory and expose it as global
  cd $(dirname "$1")
  PROJECT_DIRECTORY=$(pwd -P)
  
  # restore the current user directory as it was before this script execution
  cd $user_directory
}

buildProject() {
  # source the content of the manifest passed, that will initialize some useful 
  # variables
  . "$1"

  setupDirectories "$@"

  # verify if any dependency has been built, avoiding an unnecessary manifest 
  # pull
  if [ -z ${RECURSIVE_LEVEL+0} ]; then
    # background no-op running of a manifest container
    local image_id=$(docker run --rm -d metabarj0/manifest)

    # update the manifest
    docker exec $image_id update
  
    # preparing manifest content to be copied on the host
    docker cp $image_id:/docker.tar.bz2 $BUILD_TOOLS_DIRECTORY/
    docker kill $image_id
    tar --directory $BUILD_TOOLS_DIRECTORY \
        -xf ${BUILD_TOOLS_DIRECTORY}/docker.tar.bz2
    rm -f ${BUILD_TOOLS_DIRECTORY}/docker.tar.bz2
  fi

  # build all dependencies of this project first if there are
  if [ ! -z "$REQUIRES" ]; then
    buildDependencies "$@"
  fi
  
  # rely on some variables extracted from the manifest file that was parsed
  (
    exec \
      $BUILD_TOOLS_DIRECTORY/build.sh \
      $PROVIDES \
      $PROJECT_DIRECTORY \
      "$EXTRA_DOCKERFILE_COMMANDS"
  )
  
  # cleanup if not in a recursive call
  if [ -z ${RECURSIVE_LEVEL+0} ] || [ $RECURSIVE_LEVEL -eq 0 ]; then
    rm -rf ${BUILD_TOOLS_DIRECTORY}/docker
  fi
}

# running the script, forwarding passed arguments
checkArguments "$@"
checkFoundationImages "$@"
buildProject "$@"
