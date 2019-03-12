#!/bin/bash

set -ex

export OS=$(uname)
if [ "${OS}" = "Linux" ]; then
    export DS_ROOT_TASK=$(/usr/bin/realpath "${HOME}")

    BAZEL_URL=https://github.com/bazelbuild/bazel/releases/download/0.15.2/bazel-0.15.2-installer-linux-x86_64.sh
    BAZEL_SHA256=13eae0f09565cf17fc1c9ce1053b9eac14c11e726a2215a79ebaf5bdbf435241

    CUDA_URL=https://developer.nvidia.com/compute/cuda/9.0/Prod/local_installers/cuda_9.0.176_384.81_linux-run
    CUDA_SHA256=96863423feaa50b5c1c5e1b9ec537ef7ba77576a3986652351ae43e66bcd080c

    # From https://gitlab.com/nvidia/cuda/blob/centos7/9.0/devel/cudnn7/Dockerfile
    CUDNN_URL=http://developer.download.nvidia.com/compute/redist/cudnn/v7.2.1/cudnn-9.0-linux-x64-v7.2.1.38.tgz
    CUDNN_SHA256=cf007437b9ac6250ec63b89c25f248d2597fdd01369c80146567f78e75ce4e37

    NCCL_URL=https://s3.amazonaws.com/pytorch/nccl_2.2.13-1%2Bcuda9.0_x86_64.txz
    NCCL_SHA256=5ae976f47f9dd1caf4f5fa0da51be9ecbdeed54065d1b654ce308cc803e0af0d

    ANDROID_NDK_URL=https://dl.google.com/android/repository/android-ndk-r18b-linux-x86_64.zip
    ANDROID_NDK_SHA256=4f61cbe4bbf6406aa5ef2ae871def78010eed6271af72de83f8bd0b07a9fd3fd

    ANDROID_SDK_URL=https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip
    ANDROID_SDK_SHA256=92ffee5a1d98d856634e8b71132e8a95d96c83a63fde1099be3d86df3106def9

    SHA_SUM="sha256sum -c --strict"
    WGET=/usr/bin/wget
    TAR=tar
    XZ="pixz -9"
elif [ "${OS}" = "${TC_MSYS_VERSION}" ]; then
    if [ -z "${TASKCLUSTER_TASK_DIR}" -o -z "${TASKCLUSTER_ARTIFACTS}" ]; then
        echo "Inconsistent Windows setup: missing some vars."
        echo "TASKCLUSTER_TASK_DIR=${TASKCLUSTER_TASK_DIR}"
        echo "TASKCLUSTER_ARTIFACTS=${TASKCLUSTER_ARTIFACTS}"
        exit 1
    fi;

    # Re-export with cygpath to make sure it is sane, otherwise it might trigger
    # unobvious failures with cp etc.
    export TASKCLUSTER_TASK_DIR="$(cygpath ${TASKCLUSTER_TASK_DIR})"
    export TASKCLUSTER_ARTIFACTS="$(cygpath ${TASKCLUSTER_ARTIFACTS})"

    export DS_ROOT_TASK=${TASKCLUSTER_TASK_DIR}
    export BAZEL_VC='C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC'
    export BAZEL_SH='C:\builds\tc-workdir\msys64\usr\bin\bash'
    export TC_WIN_BUILD_PATH='C:\builds\tc-workdir\msys64\usr\bin;C:\Python36'
    export MSYS2_ARG_CONV_EXCL='//'

    mkdir -p ${TASKCLUSTER_TASK_DIR}/tmp/
    export TEMP=${TASKCLUSTER_TASK_DIR}/tmp/
    export TMP=${TASKCLUSTER_TASK_DIR}/tmp/

    BAZEL_URL=https://github.com/bazelbuild/bazel/releases/download/0.15.2/bazel-0.15.2-windows-x86_64.exe
    BAZEL_SHA256=df75c3d77f832e58e850e92fa84d1af7c024ed31d540879670fb6ea623fd2785

    CUDA_INSTALL_DIRECTORY=$(cygpath 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v9.0')

    SHA_SUM="sha256sum -c --strict"
    WGET=wget
    TAR=/usr/bin/tar.exe
    XZ="xz -9 -T0"
elif [ "${OS}" = "Darwin" ]; then
    if [ -z "${TASKCLUSTER_TASK_DIR}" -o -z "${TASKCLUSTER_ARTIFACTS}" ]; then
        echo "Inconsistent OSX setup: missing some vars."
        echo "TASKCLUSTER_TASK_DIR=${TASKCLUSTER_TASK_DIR}"
        echo "TASKCLUSTER_ARTIFACTS=${TASKCLUSTER_ARTIFACTS}"
        exit 1
    fi;

    export DS_ROOT_TASK=${TASKCLUSTER_TASK_DIR}

    BAZEL_URL=https://github.com/bazelbuild/bazel/releases/download/0.15.2/bazel-0.15.2-installer-darwin-x86_64.sh
    BAZEL_SHA256=84ee271274e7c8904a48f7894fe0569174d162c7428a19dda57fc6a6c95c628b

    SHA_SUM="shasum -a 256 -c"
    WGET=wget
    TAR=gtar
    XZ="pixz -9"
fi;

# /tmp/artifacts for docker-worker on linux,
# and task subdir for generic-worker on osx
export TASKCLUSTER_ARTIFACTS=${TASKCLUSTER_ARTIFACTS:-/tmp/artifacts}

### Define variables that needs to be exported to other processes

PATH=${DS_ROOT_TASK}/bin:$PATH
if [ "${OS}" = "Darwin" ]; then
    PATH=${DS_ROOT_TASK}/homebrew/bin/:${DS_ROOT_TASK}/homebrew/opt/node@8/bin:$PATH
fi;
export PATH

if [ "${OS}" = "Linux" ]; then
    export LD_LIBRARY_PATH=${DS_ROOT_TASK}/DeepSpeech/CUDA/lib64/:${DS_ROOT_TASK}/DeepSpeech/CUDA/lib64/stubs/:$LD_LIBRARY_PATH
    export ANDROID_SDK_HOME=${DS_ROOT_TASK}/DeepSpeech/Android/SDK/
    export ANDROID_NDK_HOME=${DS_ROOT_TASK}/DeepSpeech/Android/android-ndk-r18b/
fi;

export TF_ENABLE_XLA=0
if [ "${OS}" = "Linux" ]; then
    TF_NEED_JEMALLOC=1
elif [ "${OS}" = "${TC_MSYS_VERSION}" ]; then
    TF_NEED_JEMALLOC=0
elif [ "${OS}" = "Darwin" ]; then
    TF_NEED_JEMALLOC=0
fi;
export TF_NEED_JEMALLOC
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_MKL=0
export TF_NEED_VERBS=0
export TF_NEED_MPI=0
export TF_NEED_IGNITE=0
export TF_NEED_GDR=0
export TF_NEED_NGRAPH=0
export TF_DOWNLOAD_CLANG=0
export TF_SET_ANDROID_WORKSPACE=0
export TF_NEED_TENSORRT=0
export GCC_HOST_COMPILER_PATH=/usr/bin/gcc

if [ "${OS}" = "${TC_MSYS_VERSION}" ]; then
    export PYTHON_BIN_PATH=C:/Python36/python.exe
else
    export PYTHON_BIN_PATH=/usr/bin/python2.7
fi

## Below, define or export some build variables

# Enable some SIMD support. Limit ourselves to what Tensorflow needs.
# Also ensure to not require too recent CPU: AVX2/FMA introduced by:
#  - Intel with Haswell (2013)
#  - AMD with Excavator (2015)
# For better compatibility, AVX ony might be better.
#
# Build for generic amd64 platforms, no device-specific optimization
# See https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html for targetting specific CPUs

if [ "${OS}" = "${TC_MSYS_VERSION}" ]; then
    CC_OPT_FLAGS="/arch:AVX"
else
    CC_OPT_FLAGS="-mtune=generic -march=x86-64 -msse -msse2 -msse3 -msse4.1 -msse4.2 -mavx"
fi
BAZEL_OPT_FLAGS=""
for flag in ${CC_OPT_FLAGS};
do
    BAZEL_OPT_FLAGS="${BAZEL_OPT_FLAGS} --copt=${flag}"
done;

export CC_OPT_FLAGS

if [ "${OS}" = "Darwin" -o "${OS}" = "${TC_MSYS_VERSION}" ]; then
    BAZEL_OUTPUT_CACHE_DIR="${DS_ROOT_TASK}/.bazel_cache/"
    BAZEL_OUTPUT_CACHE_INSTANCE="${BAZEL_OUTPUT_CACHE_DIR}/output/"
    mkdir -p ${BAZEL_OUTPUT_CACHE_INSTANCE} || true

    # We need both to ensure stable path ; default value for output_base is some
    # MD5 value.
    BAZEL_OUTPUT_USER_ROOT="--output_user_root ${BAZEL_OUTPUT_CACHE_DIR} --output_base ${BAZEL_OUTPUT_CACHE_INSTANCE}"
    export BAZEL_OUTPUT_USER_ROOT
fi;

### Define build parameters/env variables that we will re-ues in sourcing scripts.
if [ "${OS}" = "${TC_MSYS_VERSION}" ]; then
    TF_CUDA_FLAGS="TF_CUDA_CLANG=0 TF_CUDA_VERSION=9.0 TF_CUDNN_VERSION=7 CUDA_TOOLKIT_PATH=\"${CUDA_INSTALL_DIRECTORY}\" CUDNN_INSTALL_PATH=\"${CUDA_INSTALL_DIRECTORY}\" TF_CUDA_COMPUTE_CAPABILITIES=\"3.0,3.5,3.7,5.2,6.0,6.1\""
else
    TF_CUDA_FLAGS="TF_CUDA_CLANG=0 TF_CUDA_VERSION=9.0 TF_CUDNN_VERSION=7 CUDA_TOOLKIT_PATH=${DS_ROOT_TASK}/DeepSpeech/CUDA CUDNN_INSTALL_PATH=${DS_ROOT_TASK}/DeepSpeech/CUDA TF_NCCL_VERSION=2.2 NCCL_INSTALL_PATH=${DS_ROOT_TASK}/DeepSpeech/CUDA TF_CUDA_COMPUTE_CAPABILITIES=\"3.0,3.5,3.7,5.2,6.0,6.1\""
fi
BAZEL_ARM_FLAGS="--config=rpi3 --config=rpi3_opt"
BAZEL_ARM64_FLAGS="--config=rpi3-armv8 --config=rpi3-armv8_opt"
BAZEL_ANDROID_ARM_FLAGS="--config=android --config=android_arm --action_env ANDROID_NDK_API_LEVEL=21 --cxxopt=-std=c++11 --copt=-D_GLIBCXX_USE_C99"
BAZEL_ANDROID_ARM64_FLAGS="--config=android --config=android_arm64 --action_env ANDROID_NDK_API_LEVEL=21 --cxxopt=-std=c++11 --copt=-D_GLIBCXX_USE_C99"
BAZEL_CUDA_FLAGS="--config=cuda"

if [ "${OS}" = "${TC_MSYS_VERSION}" ]; then
    # Somehow, even with Python being in the PATH, Bazel on windows struggles
    # with '/usr/bin/env python' ...
    #
    # We also force TMP/TEMP otherwise Bazel will pick default Windows one
    # under %USERPROFILE%\AppData\Local\Temp and with 8.3 file format convention
    # it messes with cxx_builtin_include_directory
    BAZEL_EXTRA_FLAGS="--action_env=PATH=${TC_WIN_BUILD_PATH} --action_env=TEMP=${TEMP} --action_env=TMP=${TMP}"
else
    BAZEL_EXTRA_FLAGS="--copt=-fvisibility=hidden"
fi

### Define build targets that we will re-ues in sourcing scripts.
BUILD_TARGET_LIB_CPP_API="//tensorflow:libtensorflow_cc.so"
BUILD_TARGET_GRAPH_TRANSFORMS="//tensorflow/tools/graph_transforms:transform_graph"
BUILD_TARGET_GRAPH_SUMMARIZE="//tensorflow/tools/graph_transforms:summarize_graph"
BUILD_TARGET_GRAPH_BENCHMARK="//tensorflow/tools/benchmark:benchmark_model"
BUILD_TARGET_CONVERT_MMAP="//tensorflow/contrib/util:convert_graphdef_memmapped_format"
BUILD_TARGET_TOCO="//tensorflow/contrib/lite/toco:toco"
BUILD_TARGET_LITE_BENCHMARK="//tensorflow/contrib/lite/tools/benchmark:benchmark_model"
BUILD_TARGET_LITE_LIB="//tensorflow/contrib/lite/experimental/c:libtensorflowlite_c.so"
