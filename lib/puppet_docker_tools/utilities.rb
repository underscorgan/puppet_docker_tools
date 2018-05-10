require 'docker'

class PuppetDockerTools
  module Utilities
    module_function

    # Authenticate with hub.docker.com
    def authenticate
      puts "Authentication for hub.docker.com"
      print "Email: "
      STDOUT.flush
      email = STDIN.gets.chomp
      print "Password: "
      STDOUT.flush
      password = STDIN.noecho(&:gets).chomp
      puts

      puts "going to auth to hub.docker.com as #{email}"

      Docker.authenticate!('email' => email, 'password' => password)
    end

    # Get a value from the labels on a docker image
    #
    # @param image The docker image you want to get a value from, e.g. 'puppet/puppetserver'
    # @param value The value you want to get from the labels, e.g. 'version'
    # @param namespace The namespace for the value, e.g. 'org.label-schema'
    def get_value_from_label(image, value: , namespace: )
      labels = Docker::Image.get(image).json["Config"]["Labels"]
      labels["#{namespace}.#{value.tr('_', '-')}"]
    rescue
      nil
    end

    # Get a value from a Dockerfile. Extrapolates variables and variables set in
    # the base docker image
    #
    # @param label The label containing the value you want to retrieve
    # @param namespace The namespace for the label
    # @directory The directory containing the Dockerfile, defaults to $PWD
    def get_value_from_env(label, namespace: '', directory: '.')
      text = File.read("#{directory}/Dockerfile")
      value = text.scan(/#{Regexp.escape(namespace)}\.(.+)=(.+) \\?/).to_h[label]
      # expand out environment variables
      value = get_value_from_variable(value, directory: directory, dockerfile: text) if value.start_with?('$')
      # check in higher-level image if we didn't find it defined in this docker file
      value = get_value_from_base_image(label, namespace: namespace, directory: directory) if value.nil?
      value.gsub(/\A"|"\Z/, '')
    end

    # Get the current git sha for the specified directory, using `git rev-parse HEAD`
    #
    # @param directory
    def current_git_sha(directory = '.')
      Dir.chdir directory do
        `git rev-parse HEAD`.strip
      end
    end

    # Convert timestamps from second since epoch to ISO 8601 timestamps. If the
    # given timestamp is entirely numeric it will be converted to an ISO 8601
    # timestamp, if not the parameter will be returned as passed.
    #
    # @param timestamp The timestamp to convert.
    def format_timestamp(timestamp)
      if "#{timestamp}" =~ /^\d+$/
        timestamp = Time.at(timestamp).utc.iso8601
      end
      timestamp
    end

    # Get a value from a Dockerfile
    #
    # @param key The key to read from the Dockerfile, e.g. 'from'
    # @param directory The directory containing the Dockerfile. Defaults to $PWD
    # @param dockerfile A string containing the contents of the Dockerfile [optional]
    def get_value_from_dockerfile(key, directory: '.', dockerfile: '')
      if dockerfile.empty?
        dockerfile = File.read("#{directory}/Dockerfile")
      end
      dockerfile[/^#{key.upcase} (.*$)/, 1]
    end
    private :get_value_from_dockerfile

    # Get a value from a container's base image
    #
    # @param value The value we want to get from this image's base image, e.g. 'version'
    # @param namespace The namespace for the value, e.g. 'org.label-schema'
    # @param directory The directory containing the Dockerfile, defaults to $PWD
    # @param dockerfile A string containing the contents of the Dockerfile [optional]
    def get_value_from_base_image(value, namespace:, directory: '.', dockerfile: '')
      base_image = get_value_from_dockerfile('from', directory: directory, dockerfile: dockerfile).split(':').first.split('/').last
      get_value_from_env(value, namespace: namespace, directory: "#{directory}/../#{base_image}")
    end
    private :get_value_from_base_image

    # Get a value from a variable in a Dockerfile
    #
    # @param variable The variable we want to look for in the Dockerfile, e.g. $PUPPET_SERVER_VERSION
    # @param directory The directory containing the Dockerfile, defaults to $PWD
    # # @param dockerfile A string containing the contents of the Dockerfile [optional]
    def get_value_from_variable(variable, directory: '.', dockerfile: '')
      if dockerfile.empty?
        dockerfile = File.read("#{directory}/Dockerfile")
      end
      # get rid of the leading $ for the variable
      variable[0] = ''
      dockerfile[/#{variable}=(["a-zA-Z0-9\.]+)/, 1]
    end
    private :get_value_from_variable
  end
end
