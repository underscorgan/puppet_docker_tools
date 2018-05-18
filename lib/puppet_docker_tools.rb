LIBDIR = __dir__

$:.unshift(LIBDIR) unless
$:.include?(File.dirname(__FILE__)) || $:.include?(LIBDIR)

# The main entry point is {PuppetDockerTools::Run}
class PuppetDockerTools
end
