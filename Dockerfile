
FROM        ubuntu:trusty
MAINTAINER  Robin Sommer <robin@icir.org>

# Setup packages.
RUN apt-get update
RUN apt-get -y install cmake git build-essential vim python

# Copy install-clang over.
ADD . /opt/install-clang

# Compile and install LLVM/clang.
RUN /opt/install-clang/install-clang -j 4 /opt/llvm
RUN rm -rf /opt/llvm/src/llvm/build-stage0
RUN rm -rf /opt/llvm/src/llvm/build-stage1
RUN rm -rf /opt/llvm/src/llvm/build-stage2

# Setup environment.
ENV PATH /opt/llvm/bin:$PATH


