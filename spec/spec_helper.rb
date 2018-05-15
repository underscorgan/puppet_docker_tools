require 'serverspec'
require 'docker'

# Travis builds can take time
Docker.options[:read_timeout] = 7200

# Load any shared examples or context helpers
Dir[File.join(File.dirname(__FILE__), 'support', '**', '*.rb')].sort.each { |f| require f }
