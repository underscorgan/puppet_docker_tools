require 'docker'
require 'open3'

class PuppetDockerTools
  module Utilities
    module_function

    # Push an image to hub.docker.com
    #
    # @param image_name The image to push, including the tag e.g., puppet/puppetserver:latest
    # @param stream_output Whether or not to stream output as it comes in, defaults to true
    # @return Returns an array containing the integer exitstatus of the push
    #         command and a string containing the combined stdout and stderr
    #         from the push
    def push_to_dockerhub(image_name, stream_output=true)
      Open3.popen2e("docker push #{image_name}") do |stdin, output_stream, wait_thread|
        output=''
        while line = output_stream.gets
          if stream_output
            puts line
          end
          output += line
        end
        exit_status = wait_thread.value.exitstatus
        return exit_status, output
      end
    end

    # parse build args into a hash for easier manipulation
    #
    # @param build_args array of build_args with each entry in the format 'arg=value'
    def parse_build_args(build_args)
      args_hash = {}

      build_args.each do |arg|
        fields = arg.split('=')
        key = fields.first
        # get rid of the key from the fields so we can get the value
        fields.shift
        # join the remaining fields with '=' in case the value had '=' in it
        value = fields.join('=')
        args_hash[key] = value
      end

      args_hash
    end

    # Filter build args to only include ARGs listed in the dockerfile. This is
    # meant for compatibility with old versions of docker.
    #
    # @param build_args hash of build args to filter
    # @param dockerfile the dockerfile to look for ARGs in
    def filter_build_args(build_args: , dockerfile: )
      fail "File #{dockerfile} doesn't exist!" unless File.exist? dockerfile
      text = File.read(dockerfile)

      # Docker only supports passing a single ARG on each line, so
      # look for arg, and ignore any default settings since we only care
      # whether or not the key is available
      implemented_args = text.scan(/arg +([^\n=]+)/i).flatten

      # reject any entries for args that are not in the dockerfile
      build_args.reject { |k,v|
        if implemented_args.include?(k)
          false
        else
          puts "Rejecting `--build-arg #{k}` since that ARG isn't in the Dockerfile"
          true
        end
      }
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
    # @param label The label containing the value you want to retrieve, e.g. 'version'
    # @param namespace The namespace for the label, e.g. 'org.label-schema'
    # @param directory The directory containing the Dockerfile, defaults to $PWD
    # @param dockerfile The file name for your dockerfile, defaults to 'Dockerfile'
    def get_value_from_env(label, namespace: '', directory: '.', dockerfile: 'Dockerfile')
      file = "#{directory}/#{dockerfile}"
      fail "File #{file} doesn't exist!" unless File.exist? file
      text = File.read(file)

      value = text.scan(/#{Regexp.escape(namespace)}\.(.+)=(.+) \\?/).to_h[label]
      # expand out environment variables
      # This supports either label=$variable or label="$variable"
      while ! value.nil? && (value.start_with?('$') || value.start_with?('"$'))
        # if variable is quoted, get rid of leading and trailing quotes
        value.gsub!(/\A"|"\Z/, '')
        value = get_value_from_variable(value, directory: directory, dockerfile: dockerfile, dockerfile_contents: text)
      end
      # check in higher-level image if we didn't find it defined in this docker file
      value = get_value_from_base_image(label, namespace: namespace, directory: directory, dockerfile: dockerfile) if value.nil?
      # This gets rid of leading or trailing quotes
      value.gsub(/\A"|"\Z/, '')
    end

    # Get the current git sha for the specified directory
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
    # @param timestamp The timestamp to convert
    def format_timestamp(timestamp)
      if "#{timestamp}" =~ /^\d+$/
        timestamp = Time.at(Integer(timestamp)).utc.iso8601
      end
      timestamp
    end

    # Pull a docker image
    #
    # @param image The image to pull. If the image does not include the tag to
    #        pull, it will pull all tags for that image
    def pull(image)
      if image.include?(':')
        puts "Pulling #{image}"
        PuppetDockerTools::Utilities.pull_single_tag(image)
      else
        puts "Pulling all tags for #{image}"
        PuppetDockerTools::Utilities.pull_all_tags(image)
      end
    end

    # Pull all tags for a docker image
    #
    # @param image The image to pull, e.g. puppet/puppetserver
    def pull_all_tags(image)
      Docker::Image.create('fromImage' => image)

      # Filter through existing tags of that image so we can output what we pulled
      images = Docker::Image.all('filter' => image)
      images.each do |img|
        timestamp = PuppetDockerTools::Utilities.format_timestamp(img.info["Created"])
        puts "Pulled #{img.info["RepoTags"].join(', ')}, last updated #{timestamp}"
      end
    end

    # Pull a single tag of a docker image
    #
    # @param tag The image/tag to pull, e.g. puppet/puppetserver:latest
    def pull_single_tag(tag)
      image = Docker::Image.create('fromImage' => tag)
      timestamp = PuppetDockerTools::Utilities.format_timestamp(image.info["Created"])
      puts "Pulled #{image.info["RepoTags"].first}, last updated #{timestamp}"
    end

    # Pull the specified tags
    #
    # @param tags [Array] A list of tags to pull, e.g. ['centos:7', 'ubuntu:16.04']
    def update_base_images(tags)
      tags.each do |tag|
        PuppetDockerTools::Utilities.pull(tag)
      end
    end

    # Generate the hadolint command that should be run. Hadolint is a
    # linter for dockerfiles that also validates inline bash with shellcheck.
    # For more info, see the github repo (https://github.com/hadolint/hadolint)
    #
    # @param file Dockerfile to lint, defaults to stdin
    def get_hadolint_command(file = '-')
      ignore_rules = [
        'DL3008',
        'DL3018',
        'DL4000',
        'DL4001',
      ]
      ignore_string = ignore_rules.map { |x| "--ignore #{x}" }.join(' ')

      "hadolint #{ignore_string} #{file}"
    end

    # Get a value from a Dockerfile
    #
    # @param key The key to read from the Dockerfile, e.g. 'from'
    # @param directory The directory containing the Dockerfile, defaults to $PWD
    # @param dockerfile The file name for your dockerfile, defaults to 'Dockerfile'
    # @param dockerfile_contents A string containing the contents of the Dockerfile [optional]
    def get_value_from_dockerfile(key, directory: '.', dockerfile: 'Dockerfile', dockerfile_contents: '')
      if dockerfile_contents.empty?
        file = "#{directory}/#{dockerfile}"
        fail "File #{file} doesn't exist!" unless File.exist? file
        dockerfile_contents = File.read("#{file}")
      end
      dockerfile_contents[/^#{key.upcase} (.*$)/, 1]
    end
    private :get_value_from_dockerfile

    # Get a value from a container's base image
    #
    # @param value The value we want to get from this image's base image, e.g. 'version'
    # @param namespace The namespace for the value, e.g. 'org.label-schema'
    # @param directory The directory containing the Dockerfile, defaults to $PWD
    # @param dockerfile The file name for your dockerfile, defaults to 'Dockerfile'
    # @param dockerfile_contents A string containing the contents of the Dockerfile [optional]
    def get_value_from_base_image(value, namespace:, directory: '.', dockerfile: 'Dockerfile', dockerfile_contents: '')
      base_image = get_value_from_dockerfile('from', directory: directory, dockerfile: dockerfile, dockerfile_contents: dockerfile_contents).split(':').first.split('/').last
      get_value_from_env(value, namespace: namespace, directory: "#{directory}/../#{base_image}", dockerfile: dockerfile)
    end
    private :get_value_from_base_image

    # Get a value from a variable in a Dockerfile
    #
    # @param variable The variable we want to look for in the Dockerfile, e.g. $PUPPET_SERVER_VERSION
    # @param directory The directory containing the Dockerfile, defaults to $PWD
    # @param dockerfile The file name for your dockerfile, defaults to 'Dockerfile'
    # @param dockerfile_contents A string containing the contents of the Dockerfile [optional]
    def get_value_from_variable(variable, directory: '.', dockerfile: 'Dockerfile', dockerfile_contents: '')
      if dockerfile_contents.empty?
        file = "#{directory}/#{dockerfile}"
        fail "File #{file} doesn't exist!" unless File.exist? file
        dockerfile_contents = File.read("#{file}")
      end
      variable_clone = String.new(variable)
      # get rid of the leading $ for the variable
      variable_clone[0] = ''

      dockerfile_contents[/#{variable_clone}=([$"'a-zA-Z0-9\.]+)/, 1]
    end
    private :get_value_from_variable
  end
end
