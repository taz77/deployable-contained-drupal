-include env_make

NGINX_VER ?= 1.17.8
DRUPAL_REF ?= 8.8.5
DRUPAL_GIT ?= https://git.drupalcode.org/project/drupal.git
ALPINE_VER ?= 3.11
APK_MAIN ?= http://dl-cdn.alpinelinux.org/alpine/v3.11/main
APK_COMMUNITY ?= http://dl-cdn.alpinelinux.org/alpine/v3.11/community
PHP_URL ?= https://www.php.net/get/php-7.4.5.tar.xz/from/this/mirror
PHP_ASC_URL ?= https://www.php.net/get/php-7.4.5.tar.xz.asc/from/this/mirror
PHP_VER ?= 7.4.5
INSTALL_DRUPAL ?= ""
APPSOURCE ?= ""

REPO = bowens/deployable-contained-drupal
NAME = deployable-drupal-$(NGINX_VER)

ifneq ($(STABILITY_TAG),)
    ifneq ($(TAG),latest)
        override TAG := $(TAG)-$(STABILITY_TAG)
    endif
endif

ifeq ($(TAG),)
  TAG ?= $(NGINX_VER)
endif

.PHONY: build test push shell run start stop logs clean release

default: build

build:
	if [ ! -z ${INSTALL_DRUPAL} ]; then \
		composer create-project drupal/recommended-project app; \
	elif [ ! -z ${APPSOURCE} ]; then \
		mkdir app; \
		cp -a ${APPSOURCE} app/; \
	else \
			mkdir app; \
	    { \
	        echo '<!doctype html><html><head><title>Deployable Drupal Container!</title></head>'; \
	        echo '<body><p>You have reached the <strong>Deployable Drupal Container</strong> default index file.</body></html>'; \
	    } | tee app/index.html; \
	    { \
	        echo '<?php print "<p>You have reached the <strong>Deployable Drupal Container</strong> default <i>PHP</i> index file."?>'; \
	    } | tee app/index.php; \
	fi; \

	docker build -t $(REPO):$(TAG) \
		--build-arg NGINX_VER=$(NGINX_VER) \
		--build-arg DRUPAL_REF=${DRUPAL_REF} \
		--build-arg DRUPAL_GIT=${DRUPAL_GIT} \
		--build-arg ALPINE_VER=${ALPINE_VER} \
		--build-arg APK_MAIN=${APK_MAIN} \
		--build-arg APK_COMMUNITY=${APK_COMMUNITY} \
		--build-arg PHP_URL=${PHP_URL} \
		--build-arg PHP_ASC_URL=${PHP_ASC_URL} \
		--build-arg PHP_VER=${PHP_VER} \
		--build-arg INSTALL_DRUPAL=${INSTALL_DRUPAL} \
		--build-arg DRUPAL_REF=${DRUPAL_REF} \
		--build-arg DRUPAL_GIT=${DRUPAL_GIT} \
		./

push:
	docker push $(REPO):$(TAG)

shell:
	docker run --rm --name $(NAME) -i -t $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) /bin/bash

run:
	docker run --rm --name $(NAME) -e DEBUG=1 $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) $(CMD)

start:
	docker run -d --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG)

stop:
	docker stop $(NAME)

logs:
	docker logs $(NAME)

clean:
	-docker rm -f $(NAME)

release: build push
