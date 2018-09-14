require 'time'

Gem::Specification.new do |gem|
  gem.name    = 'puppet_docker_tools'
  gem.version = %x(git describe --tags).tr('-', '.').chomp
  gem.date    = Date.today.to_s

  gem.summary     = "Puppet tools for building docker images"
  gem.description = "Utilities for building and publishing the docker images at https://hub.docker.com/u/puppet"
  gem.license     = "Apache-2.0"

  gem.authors  = ['Puppet, Inc.']
  gem.email    = 'release@puppet.com'
  gem.homepage = 'https://github.com/puppetlabs/puppet_docker_tools'
  gem.specification_version = 3
  gem.required_ruby_version = '~> 2.1'

  #dependencies
  # MIT licensed: https://rubygems.org/gems/rspec
  gem.add_runtime_dependency('rspec', '~> 3.0')
  # MIT licensed: https://rubygems.org/gems/docopt
  gem.add_runtime_dependency('docopt', '~> 0.6')

  gem.require_path = 'lib'
  gem.bindir       = 'bin'
  gem.executables  = ['puppet-docker']

  # Ensure the gem is built out of versioned files
  gem.files = Dir['{bin,lib,spec}/**/*', 'README*', 'LICENSE*'] & %x(git ls-files -z).split("\0")
  gem.test_files = Dir['spec/**/*_spec.rb']
end
