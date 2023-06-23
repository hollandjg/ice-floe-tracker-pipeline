FROM julia:1.9.0-bullseye

ENV TERM=xterm

RUN apt-get clean && apt-get update && \
apt-get install -y git

RUN git clone https://github.com/WilhelmusLab/ice-floe-tracker-pipeline.git && \ 
git clone https://github.com/WilhelmusLab/IceFloeTracker.jl.git

RUN julia -e 'using Pkg; Pkg.activate("/usr/local/bin/IceFloeTracker.jl"); ENV["PYTHON"]=""; Pkg.build("PyCall"); Pkg.instantiate()'

RUN cd ../ice-floe-tracker-pipeline && \
julia -e 'using Pkg; Pkg.activate("/usr/local/bin/ice-floe-tracker-pipeline"); Pkg.rm ("IceFloeTracker.jl"); Pkg.add("../IceFloeTracker.jl"); Pkg.instantiate(); Pkg.build()'

COPY ./workflow/scripts/ice-floe-tracker.jl /usr/local/bin

RUN chmod a+x /usr/local/bin/ice-floe-tracker.jl

CMD [ "/bin/bash", "-c" ]