require 'puppet_docker_tools/utilities/dockerfile'
require 'docker'

class PuppetDockerTools
  module Utilities
    module_function

    def authenticate
      puts "Authentication for hub.docker.com"
      print "Username: "
      STDOUT.flush
      username = gets.chomp
      print "Password: "
      STDOUT.flush
      password = STDIN.noecho(&:gets).chomp
      puts
      print "Email: "
      STDOUT.flush
      email = gets.chomp

      puts "going to auth to hub.docker.com as #{username} with #{email}"

      Docker.authenticate!('username' => username, 'password' => password, 'email' => email)
    end

    def get_value_from_label(image, value)
      labels = Docker::Image.get("#{PuppetDockerTools::REPOSITORY}/#{image}").json["Config"]["Labels"]
      labels["#{PuppetDockerTools::NAMESPACE}.#{value.tr('_', '-')}"]
    rescue
      nil
    end

    def current_git_sha(directory = '.')
      Dir.chdir directory do
        `git rev-parse HEAD`.strip
      end
    end
  end
end
