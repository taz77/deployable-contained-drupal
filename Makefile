-include env_make

NGINX_VER ?= 1.17.8
DRUPAL_REF ?= 8.8.2
DRUPAL_GIT ?= https://git.drupalcode.org/project/drupal.git
ALPINE_VER ?= 3.11
APK_MAIN ?= http://dl-cdn.alpinelinux.org/alpine/v3.11/main
APK_COMMUNITY ?= http://dl-cdn.alpinelinux.org/alpine/v3.11/community
PHP_URL ?= https://www.php.net/get/php-7.4.3.tar.xz/from/this/mirror
PHP_ASC_URL ?= https://www.php.net/get/php-7.4.3.tar.xz.asc/from/this/mirror
PHP_VER ?= 7.4.3
INSTALL_DRUPAL ?= 0
DRUPAL_REF ?= 8.8.2
DRUPAL_GIT ?= https://git.drupalcode.org/project/drupal.git

REPO = taz77/deployable-contained-drupal
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
	git clone --branch ${DRUPAL_REF} ${DRUPAL_GIT} app; 
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
