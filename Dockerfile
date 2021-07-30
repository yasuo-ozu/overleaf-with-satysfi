# ---------------------------------------------
# Overleaf Community Edition (overleaf/overleaf)
# ---------------------------------------------

ARG SHARELATEX_BASE_TAG=sharelatex/sharelatex-base:latest
FROM $SHARELATEX_BASE_TAG

WORKDIR /var/www/sharelatex

# Install SATySFi
# ---------------
#

ENV SATYSFI_VERSION=0.0.6-53-g2867e4d9
ENV SATYROGRAPHOS_VERSION=0.0.2.10
ENV OPAM_VERSION=2.0.8

RUN bash -c "curl https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh > ./installer.sh" \
  && chmod +x ./installer.sh \
  && echo "/usr/bin" | ./installer.sh --version ${OPAM_VERSION} \
  && opam init --disable-sandboxing -n && opam update -y \
  && opam repository add --all-switches satysfi-external https://github.com/gfngfn/satysfi-external-repo.git \
  && opam repository add --all-switches satyrographos-repo https://github.com/na4zagin3/satyrographos-repo.git \
  && opam install -y depext \
  && apt-get update \
  && apt-get install -y pkg-config \
  && opam depext conf-pkg-config \
  && opam depext satysfi.${SATYSFI_VERSION} satysfi-dist.${SATYSFI_VERSION} satyrographos.${SATYROGRAPHOS_VERSION} \
#&& rm -rf /var/lib/apt/lists/* \
  && opam install -y satysfi.${SATYSFI_VERSION} satysfi-dist.${SATYSFI_VERSION} satyrographos.${SATYROGRAPHOS_VERSION} \
  && rm -r /usr/share/satysfi \
  && opam exec -- satyrographos install --copy --output /usr/share/satysfi/dist \
  && chmod -R 0755 /usr/share/satysfi \
  && cp /root/.opam/default/bin/satysfi /usr/bin/satysfi


# Add required source files
# -------------------------
ADD ${baseDir}/genScript.js /var/www/sharelatex/genScript.js
ADD ${baseDir}/services.js /var/www/sharelatex/services.js

# Checkout services
# -----------------
RUN node genScript checkout | bash \
  \
# Store the revision for each service
# ---------------------------------------------
&&  node genScript revisions | bash > /var/www/revisions.txt \
  \
# Cleanup the git history
# -------------------
&&  node genScript cleanup-git | bash

# Install npm dependencies
# ------------------------
RUN node genScript install | bash

# Compile
# --------------------
RUN node genScript compile | bash

# Links CLSI synctex to its default location
# ------------------------------------------
RUN ln -s /var/www/sharelatex/clsi/bin/synctex /opt/synctex


# Copy runit service startup scripts to its location
# --------------------------------------------------
ADD ${baseDir}/runit /etc/service


# Configure nginx
# ---------------
ADD ${baseDir}/nginx/nginx.conf.template /etc/nginx/templates/nginx.conf.template
ADD ${baseDir}/nginx/sharelatex.conf /etc/nginx/sites-enabled/sharelatex.conf


# Configure log rotation
# ----------------------
ADD ${baseDir}/logrotate/sharelatex /etc/logrotate.d/sharelatex
RUN chmod 644 /etc/logrotate.d/sharelatex


# Copy Phusion Image startup scripts to its location
# --------------------------------------------------
COPY ${baseDir}/init_scripts/ /etc/my_init.d/

# Copy app settings files
# -----------------------
COPY ${baseDir}/settings.js /etc/sharelatex/settings.js

# Copy grunt thin wrapper
# -----------------------
ADD ${baseDir}/bin/grunt /usr/local/bin/grunt
RUN chmod +x /usr/local/bin/grunt

# Set Environment Variables
# --------------------------------
ENV SHARELATEX_CONFIG /etc/sharelatex/settings.js

ENV WEB_API_USER "sharelatex"

ENV SHARELATEX_APP_NAME "Overleaf Community Edition"

ENV OPTIMISE_PDF "true"

ENV ADDITIONAL_TEXT_EXTENSIONS "saty,satyg,satyh"


EXPOSE 80

WORKDIR /

ENTRYPOINT ["/sbin/my_init"]

