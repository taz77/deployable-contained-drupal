# Deployable Docker4Drupal
**Problem:** Need a Docker container for production desployments that is geared toward automated deployments and not local development.

**Requirements**
 * Nginx
 * PHP-FPM
 * Codebase in contain and not a volume
 * Mountable volume for user uploaded content
 * Template for dynamica creation of settings.php from ENV vars

There are a lot of Docker containers for Drupal, PHP, and Nginx; however, there seems to be none that fulfilled the requirements listed above hence this repository was born.

## Build Enviornment Variables

We use GNU Make to assist in building the container. Why? Because a way was needed to handle Drupal source code before doing the Dockerbuild. Using GNU Make with Docker builds is a common pattern.
Therefore, there are some requirements of the build environment that must be met in order to proceed.

**Build Environment Requirements**
 * GNU Make
 * PHP Composer

Maximum flexibility has been a goal of this project so a lot of variables can be customized in the build via [build args](https://docs.docker.com/engine/reference/commandline/build/#set-build-time-variables---build-arg). Whereever possible, the option has been provided to change download locations and to use alternate repositories such as a local cache. The Alpine APK repositories can be changed to use a local proxy/mirror. You can also alter the download location of the PHP binaries. Defaults are specified for all of these but you can choose to change them. 

The Make process will pass the build arguements to the Docker process via envrionment variables.

| Variable        | Value           |
| ------------- |:-------------|
| ALPINE_VER     | Version of Alpine to use |
| NGINX_VER      | Nginx version      |
| APK_MAIN       | URL to Main APK repo      |
| APK_COMMUNITY       | URL to Community APK repo      |
| APK_EDGE       | URL to Edge APK repo      |
| PHP_URL       | URL to download PHP      |
| PHP_ASC_URL       | URL to download PHP asc file      |
| INSTALL_DRUPAL  | Install Drupal set to any value |
| APPSOURCE      | Path to your source code |

Defaults are set for all variables, they are not required to build.

## Drupal Installation

If `INSTALL_DRUPAL` variable is set, composer is used to create a blank Drupal project using the `drupal/recommended-project` process outlined on [Drupal.org](https://www.drupal.org/docs/develop/using-composer/using-composer-to-install-drupal-and-manage-dependencies).

To deploy your own source code to this container set the variable `APPSOURCE` to the path of your Drupal8 code that follows the same pattern as the `recommended-project` (i.e. Drupal source is in a sub folder named "web"). _**Trailing slash is required at the end of the path.**_

If either of the above options are not provided then a generic html and php file is placed into the web director.

## Acknowledgement
A lot of the code here was borrowed from the [Wodby project](https://github.com/wodby). They have some very well built base images that are highly configurable via environment
files but their Nginx setup used PHP on a seperate container.
