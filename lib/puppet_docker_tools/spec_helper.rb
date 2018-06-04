require 'serverspec'
require 'docker'

# Travis builds can take time
Docker.options[:read_timeout] = 36000

# Load any shared examples or context helpers
Dir[File.join(File.dirname(__FILE__), '..', '..', 'spec', 'support', '**', '*.rb')].sort.each { |f| require f }
