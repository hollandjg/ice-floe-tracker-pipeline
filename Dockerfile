FROM julia:1.9.0-bullseye

ENV TERM=xterm

RUN git clone https://github.com/WilhelmusLab/ice-floe-tracker-pipeline.git && \ 
git clone https://github.com/WilhelmusLab/IceFloeTracker.jl.git && \
cd IceFloeTracker.jl

RUN julia -e 'using Pkg; Pkg.activate("/IceFloeTracker.jl"); ENV["PYTHON"]=""; Pkg.build("PyCall"); Pkg.instantiate()'

RUN cd ../ice-floe-tracker-pipeline && \
julia -e 'using Pkg; Pkg.activate("."); Pkg.rm ("IceFloeTracker.jl"); Pkg.add("../IceFloeTracker.jl"); Pkg.instantiate(); Pkg.build()'

COPY ./workflow/scripts/ice-floe-tracker.jl /usr/local/bin

RUN chmod a+x /usr/local/bin/ice-floe-tracker.jl

CMD [ "/bin/bash", "-c" ]
