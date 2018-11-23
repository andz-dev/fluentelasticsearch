# or v0.12-onbuild
FROM fluent/fluentd:v1.3-onbuild

# Some information
LABEL Maintainer "Andreas Elser"
LABEL Version "1.3"
LABEL Name "fluentd with elasticsearch plugin"

# below RUN includes plugin as examples elasticsearch is not required
# you may customize including plugins as you wish
RUN apk add --virtual .build-deps \
       sudo build-base ruby-dev \
       && sudo gem install \
       fluent-plugin-elasticsearch \
       && sudo gem sources --clear-all \
       && apk del .build-deps \
       && rm -rf /var/cache/apk/* \
       && gem cleanup