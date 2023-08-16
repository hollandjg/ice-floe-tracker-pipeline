FROM julia:1.9-bookworm

ENV TERM=xterm
ENV JULIA_PROJECT=/opt/ice-floe-tracker-pipeline
ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia

RUN apt-get -y update && \
    apt-get install -y git python3.10 && \
    apt-get install -y python3-pyproj python3-rasterio && \
    rm -rf /var/lib/apt/list/* 

WORKDIR /opt

RUN git clone https://github.com/WilhelmusLab/ice-floe-tracker-pipeline.git

RUN /usr/local/julia/bin/julia --project="/opt/ice-floe-tracker-pipeline" -e 'ENV["PYTHON"]="/usr/local/bin/python"; using Pkg; Pkg.build()' 

COPY workflow/scripts/ice-floe-tracker.jl /usr/local/bin/ice-floe-tracker.jl

RUN chmod a+x /usr/local/bin/ice-floe-tracker.jl

ENV JULIA_DEPOT_PATH="$HOME/.julia:$JULIA_DEPOT_PATH"

CMD [ "/bin/bash", "-c" ]
