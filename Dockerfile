FROM julia:1.11-bookworm

# DEPENDENCIES
#===========================================
ENV TERM=xterm
RUN apt-get -y update && \
    apt-get install -y git python3.11 python3-pip python3-venv gdal-bin libgdal-dev

# Python environment build
#===========================================
COPY ./PythonSetup.jl /opt/PythonSetup.jl
RUN julia --project="/opt/PythonSetup.jl" "/opt/PythonSetup.jl/setup.jl"

# IFT Pipeline package build
#===========================================
COPY ./IFTPipeline.jl /opt/IFTPipeline.jl
RUN julia --project="/opt/IFTPipeline.jl" -e 'using Pkg; Pkg.instantiate();'

# Test the package
RUN julia --project="/opt/IFTPipeline.jl" -e 'using Pkg; Pkg.test();'

# CLI setup
#===========================================
SHELL ["/bin/bash", "-c"]
ENTRYPOINT ["julia", "--project=/opt/IFTPipeline.jl", "/opt/IFTPipeline.jl/src/cli.jl" ]
