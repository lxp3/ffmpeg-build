# Use manylinux_2_28 (based on AlmaLinux 8, glibc 2.28)
FROM quay.io/pypa/manylinux_2_28_x86_64

# Install build dependencies for FFmpeg
# AlmaLinux uses dnf as the package manager
# RUN dnf update -y && \
#     dnf install -y \
#     make \
#     gcc \
#     gcc-c++ \
#     diffutils \
#     curl \
#     tar \
#     bzip2 \
#     nasm \
#     yasm \
#     pkgconfig \
#     ca-certificates

# Set working directory
WORKDIR /data

# Default command
CMD ["/bin/bash"]
