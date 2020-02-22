# Deployable Docker4Drupal
**Problem:** Need a Docker container for production desployments that is geared toward automated deployments and not local development.

**Requirements**
 * Nginx
 * PHP-FPM
 * Codebase in contain and not a volume
 * Mountable volume for user uploaded content
 * Template for dynamica creation of settings.php from ENV vars

There are a lot of Docker containers for Drupal, PHP, and Nginx; however, there seems to be none that fulfilled the requirements listed above hence this repository was born.

## Build Arguements
Maximum flexibility has been a goal of this project so a lot of variables can be customized in the build via [build args](https://docs.docker.com/engine/reference/commandline/build/#set-build-time-variables---build-arg). Whereever possible, the option has been provided to change download locations and to use alternate repositories such as a local cache. The Alpine APK repositories can be changed to use a local proxy/mirror. You can also alter the download location of the PHP binaries. Defaults are specified for all of these but you can choose to change them. See the top of the `Dockerfile` for examples.

| Arguement        | Value           |
| ------------- |:-------------|
| ALPINE_VER     | Version of Alpine to use |
| NGINX_VER      | Nginx version      |
| APK_MAIN       | URL to Main APK repo      |
| APK_COMMUNITY       | URL to Community APK repo      |
| APK_EDGE       | URL to Edge APK repo      |
| PHP_URL       | URL to download PHP      |
| PHP_ASC_URL       | URL to download PHP asc file      |


## Acknowledgement
A lot of the code here was borrowed from the [Wodby project](https://github.com/wodby). They have some very well built base images that are highly configurable via environment
files but their Nginx setup used PHP on a seperate container.
