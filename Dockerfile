FROM julia:1.9.0-bullseye

ENV TERM=xterm 

RUN apt-get install -y wget python3-pip git python3.10

WORKDIR /opt

RUN git clone https://github.com/WilhelmusLab/ice-floe-tracker-pipeline.git

RUN julia -e 'using Pkg; Pkg.activate("/opt/ice-floe-tracker-pipeline"); Pkg.build()'

RUN chmod a+x /opt/ice-floe-tracker-pipeline/workflow/scripts/ice-floe-tracker.jl

CMD [ "/bin/bash", "-c" ]