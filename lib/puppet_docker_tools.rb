LIBDIR = __dir__

$:.unshift(LIBDIR) unless
$:.include?(File.dirname(__FILE__)) || $:.include?(LIBDIR)

class PuppetDockerTools
  REPOSITORY = ENV['DOCKER_REPOSITORY'] || 'puppet'
  NO_CACHE = ENV['DOCKER_NO_CACHE'] || false
  TAG = ENV['DOCKER_IMAGE_TAG'] || 'latest'
  NAMESPACE = ENV['DOCKER_NAMESPACE'] || 'org.label-schema'
end
