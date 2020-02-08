# Deployable Docker4Drupal
**Problem:** Need a Docker container for production desployments that is geared toward automated deployments and not local development.

**Requirements**
 * Nginx
 * PHP-FPM
 * Codebase in contain and not a volume
 * Mountable volume for user uploaded content
 * Template for dynamica creation of settings.php from ENV vars

There are a lot of Docker containers for Drupal, PHP, and Nginx; however, there seems to be none that fulfilled the requirements listed above hence this repository was born.


# Acknowledgement
A lot of the code here was borrowed from the [Wodby project](https://github.com/wodby). They have some very well built base images that are highly configurable via environment
files but their Nginx setup used PHP on a seperate container.
