# Introduction

Using the [fluentd onbuild image](https://hub.docker.com/r/fluent/fluentd/) in this scenario (it also affects the ready to use image) inside a company network environment with SSL CA certificates causes in an SSL error.
Because the gem package manager can't download any ressources the image will be corrupted.

So I tried some ways to import and use the certificates inside the container image to install the necessary packages based on the fluentd image and the underlying [Alpine image](https://hub.docker.com/_/alpine/).

I also installed my company certificates on my Linux host and the package managers like `apt` and `apk` runs well on the host and the container I didn't mentioned that I will have trouble inside the container images because the SSL certifications for other package manager...

## The manual steps

After some trial and error with the Dockerfile I've searched for a solution and found the workaround to manually update gem and then install the elasticsearch plugin.
- [SSL upgrades on rubygems.org and RubyInstaller versions](https://gist.github.com/luislavena/f064211759ee0f806c88#installing-using-update-packages-new)

Although this guide describes the SSL certification problem it is more than 2 years old and the last update refferred to the official guide.
- [SSL CERTIFICATE UPDATES](https://guides.rubygems.org/ssl-certificate-update/#installing-using-update-packages)

But following the "official" way doesn't help very much because there isn't a problem with an old OpenSSL version...

An additional workaround I found was to use the insecure HTTP conenction to the rubygems packages. I've tested the steps described in the link below but it doesn't make sense to disable HTTPS feature because of some certification issues...
- [How to tell gem command not to use SSL](https://stackoverflow.com/questions/20399531/how-to-tell-gem-command-not-to-use-ssl)

### Trial and error inside an Alpine container

Because the manual steps above weren't successful for me I started my own Alpine container.

```sh
$ docker run --name rubytest -it --rm -v PATH_TO_SSL_CERTS/:/ssl_cert/ alpine:3.8 /bin/sh
```

I mapped my SSL certifications from the host to the container and started a new terminal.
After that I copied the SSL certs from `/ssl_cert` to `/usr/local/share/ca-certificates/` and run the `update-ca-certificates`.
[The following guide helped me to find the correct cert paths for Alpine.](https://hackernoon.com/alpine-docker-image-with-secured-communication-ssl-tls-go-restful-api-128eb6b54f1f)

**Note:** If a warning like "WARNING: CERT-FILE does not contain exactly one certificate or CRL: skipping" check your *.crt files. It is important to have one file for each certificate!

After the certification update I installed `wget` via `apk add wget` and downloaded the latest rubygem package from the website.

```sh
wget https://rubygems.org/gems/rubygems-update-2.7.8.gem
```

Now the download should also work with gem and I exited the container.

## Build image

After my tests the Dockerfile was changed for the new experience I gained. So I decided to use an build argument because this can be passed as a docker-compose build context argument.
The argument gets the host path to the certification file and the files are copied later then to the certification system directory.

Also create a directory like `certs` inside your project and copy the certificates to it.

```Dockerfile
# or v0.12-onbuild
FROM fluent/fluentd:v1.3-onbuild

# This section is necessary for import company CA certificates
ARG certfile=./certs/

# Copy the certification files
COPY ${certfile} /usr/local/share/ca-certificates/

# Update the certificates
RUN update-ca-certificates

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

# Delete the company certificates from the container image
RUN rm -rf /usr/local/share/ca-certificates/ \
       && update-ca-certificates
```

You can build the image via `docker build --build-arg certfile=./certs/ -t fluentd-local .` inside the projects directory.

The certificates will be used to install additional packages and after that they will be removed from the container.

## Compose

If you want to use the fluentd container image on your Compose Stack you can use the following compose example:

```yml
...
fluentd:
    build:
      context: ./fluentd/
      args:
        - certfile=./ssl_cert/
...
```

You need to copy the build source to your compose file structure - then change the build context if necessary.

## Ready to use image

If you don't want to build the images yourself you can also use the prebuilt images provided on Docker Hub:
- [fluentd with elasticsearch]()