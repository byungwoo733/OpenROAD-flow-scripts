#!/bin/bash
# This script builds the OpenROAD tools locally

# Exit on first error
set -e

#OPENROAD_MODULES = OpenROAD yosys TritonRoute OpeNPDN
src_path="OpenROAD/src"
build_path="OpenROAD/build/src"

# Choose install method
if which docker &> /dev/null; then
  build_method="DOCKER"
else
  build_method="LOCAL"
fi

# Clone repositories
git submodule update --init --recursive

# --recursive doesn't recurse all the way
(cd OpenROAD && git submodule update --init --recursive)
(cd $src_path/OpenDB && git submodule update --init --recursive)

if ! [ -d $src_path/yosys ]; then
  echo "INFO: Cloning repository 'yosys'"
  git clone --recursive https://github.com/The-OpenROAD-Project/yosys.git $src_path/yosys
  sed -i 's/^CONFIG := clang$/#CONFIG := clang/g' $src_path/yosys/Makefile
  sed -i 's/^# CONFIG := gcc$/CONFIG := gcc/g' $src_path/yosys/Makefile
else
  echo "INFO: Updating repository 'yosys'"
  (cd $src_path/yosys && git pull && git submodule update --init --recursive)
fi

if ! [ -d $src_path/TritonRoute ]; then
  echo "INFO: Cloning repository 'TritonRoute'"
  git clone --recursive https://github.com/The-OpenROAD-Project/TritonRoute.git $src_path/TritonRoute --branch alpha2
else
  echo "INFO: Updating repository 'TritonRoute'"
  (cd $src_path/TritonRoute && git pull && git submodule update --init --recursive)
fi


# Docker build
if [ "$build_method" == "DOCKER" ]; then
  docker build -t openroad -f $src_path/../Dockerfile $src_path/..
  docker build -t openroad/tritonroute -f $src_path/TritonRoute/Dockerfile $src_path/TritonRoute
  docker build -t openroad/yosys -f $src_path/yosys/Dockerfile $src_path/yosys
  docker build -t openroad/flow -f Dockerfile .

# Local build
elif [ "$build_method" == "LOCAL" ]; then
  mkdir -p $build_path/yosys
  (cd $src_path/yosys && make -j$(nproc) TCL_VERSION=tcl8.5)
  cp $src_path/yosys/yosys* $build_path/yosys/
  cp -r $src_path/yosys/share $build_path/yosys/

  mkdir -p $src_path/TritonRoute/build $build_path/TritonRoute
  (cd $src_path/TritonRoute/build && cmake .. && make -j$(nproc))
  cp $src_path/TritonRoute/build/* $build_path/TritonRoute/

  mkdir -p $src_path/../build
  (cd OpenROAD/build && cmake .. && make -j$(nproc))
else
  echo "ERROR: No valid build method found"
  exit 1
fi
