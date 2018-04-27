LIBDIR = __dir__

$:.unshift(LIBDIR) unless
$:.include?(File.dirname(__FILE__)) || $:.include?(LIBDIR)

class PuppetDockerTools
end
