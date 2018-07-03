require 'date'
require 'docker'
require 'json'
require 'rspec/core'
require 'time'
require 'puppet_docker_tools/utilities'
require 'puppet_docker_tools/spec_helper'

class PuppetDockerTools
  class Runner
    attr_accessor :directory, :repository, :namespace, :dockerfile

    def initialize(directory: , repository: , namespace: , dockerfile: )
      @directory = directory
      @repository = repository
      @namespace = namespace
      @dockerfile = dockerfile

      file = "#{directory}/#{dockerfile}"
      fail "File #{file} doesn't exist!" unless File.exist? file
    end

    # Build a docker image from a directory
    #
    # @param no_cache Whether or not to use existing layer caches when building
    #        this image. Defaults to using the cache (no_cache = false).
    # @param version Set the version for the container explicitly. Will get
    #        passed as the 'version' buildarg.
    # @param build_args Pass arbitrary buildargs to the container build.
    #        Expected to be an array of strings, each string formatted like
    #        'arg=value'.
    # @param latest Whether or not to build the latest tag along with the
    #        versioned image build.
    def build(no_cache: false, version: nil, build_args: [], latest: true)
      image_name = File.basename(directory)
      build_args_hash = {
        'vcs_ref' => PuppetDockerTools::Utilities.current_git_sha(directory),
        'build_date' => Time.now.utc.iso8601
      }

      # if version is passed in, add that into the build_args hash
      # **NOTE** if both `version` and `build_args` includes `version=something`
      #          the value in `build_args` takes precedence
      build_args_hash['version'] = version unless version.nil?

      # Convert the build_args array to a hash, and merge it with the values
      # that have already been set
      if Array(build_args).any?
        build_args_hash.merge!(PuppetDockerTools::Utilities.parse_build_args(Array(build_args)))
      end

      build_args_hash = PuppetDockerTools::Utilities.filter_build_args(build_args: build_args_hash, dockerfile: "#{directory}/#{dockerfile}")

      # This variable is meant to be used for building the non-latest tagged build
      # If the version was set via `version` or `build_args`, use that. If not,
      # use `get_value_from_env` to parse that value from the dockerfile.
      #
      # If version hasn't been passed in via `version` or `build_args` there's
      # no need to add the version from `get_value_from_env` to the
      # build_args_hash, dockerfiles should not be using both hardcoded versions
      # and versions passed in to the dockerfile with an `ARG`
      version = build_args_hash['version'] || PuppetDockerTools::Utilities.get_value_from_env('version', namespace: namespace, directory: directory, dockerfile: dockerfile)

      path = "#{repository}/#{image_name}"

      build_options = {'dockerfile' => dockerfile, 'buildargs' => "#{build_args_hash.to_json}"}

      if no_cache
        puts "Ignoring cache for #{path}"
        build_options['nocache'] = true
      end

      if latest
        puts "Building #{path}:latest"

        # 't' in the build_options sets the tag for the image we're building
        build_options['t'] = "#{path}:latest"

        Docker::Image.build_from_dir(directory, build_options)
      end

      if version
        puts "Building #{path}:#{version}"

        build_options['t'] = "#{path}:#{version}"
        Docker::Image.build_from_dir(directory, build_options)
      end
    end

    # Run hadolint on the Dockerfile in the specified directory. This will run
    # hadolint inside of a container. To run a locally-installed hadolint binary
    # see local_lint.
    #
    def lint
      hadolint_container = 'hadolint/hadolint'

      # make sure we have the container locally
      PuppetDockerTools::Utilities.pull("#{hadolint_container}:latest")
      container = Docker::Container.create('Cmd' => ['/bin/sh', '-c', "#{PuppetDockerTools::Utilities.get_hadolint_command}"], 'Image' => hadolint_container, 'OpenStdin' => true, 'StdinOnce' => true)
      # This container.tap startes the container created above, and passes directory/Dockerfile to the container
      container.tap(&:start).attach(stdin: "#{directory}/#{dockerfile}")
      # Wait for the run to finish
      container.wait
      exit_status = container.json['State']['ExitCode']
      unless exit_status == 0
        fail container.logs(stdout: true, stderr: true)
      end
    end

    # Run hadolint Dockerfile linting using a local hadolint executable. Executable
    # found based on your path.
    def local_lint
      output, status = Open3.capture2e(PuppetDockerTools::Utilities.get_hadolint_command("#{directory}/#{dockerfile}"))
      fail output unless status == 0
    end

    # Push an image to $repository
    #
    # @param latest Whether or not to push the latest tag along with the
    #        versioned image build.
    def push(latest: true)
      image_name = File.basename(directory)
      path = "#{repository}/#{image_name}"
      version = PuppetDockerTools::Utilities.get_value_from_label(path, value: 'version', namespace: namespace)

      # We always want to push a versioned label
      unless version
        fail "No version specified in #{dockerfile} for #{path}"
      end

      puts "Pushing #{path}:#{version}"
      exitstatus, _ = PuppetDockerTools::Utilities.push_to_docker_repo("#{path}:#{version}")
      unless exitstatus == 0
        fail "Pushing #{path}:#{version} failed!"
      end

      if latest
        puts "Pushing #{path}:latest"
        exitstatus, _ = PuppetDockerTools::Utilities.push_to_docker_repo("#{path}:latest")
        unless exitstatus == 0
          fail "Pushing #{path}:latest failed!"
        end
      end
    end

    # Update vcs-ref and build-date labels in the Dockerfile
    #
    def rev_labels
      file = File.join(directory, dockerfile)

      values_to_update = {
        "#{namespace}.vcs-ref" => PuppetDockerTools::Utilities.current_git_sha(directory),
        "#{namespace}.build-date" => Time.now.utc.iso8601
      }

      text = File.read(file)
      values_to_update.each do |key, value|
        original = text.clone
        text = text.gsub(/#{key}=\"[a-z0-9A-Z\-:]*\"/, "#{key}=\"#{value}\"")
        puts "Updating #{key} in #{file}" unless original == text
      end

      File.open(file, 'w') { |f| f.puts text }
    end

    # Run spec tests
    #
    def spec
      tests = Dir.glob("#{directory}/spec/*_spec.rb")
      test_files = tests.map { |test| File.basename(test, '.rb') }

      puts "Running RSpec tests from #{File.expand_path("#{directory}/spec")} (#{test_files.join ","}), this may take some time"
      success = true
      tests.each do |test|
        Open3.popen2e("rspec spec #{test}") do |stdin, output_stream, wait_thread|
          while line = output_stream.gets
            puts line
          end
          exit_status = wait_thread.value.exitstatus
          success = success && (exit_status == 0)
        end
      end

      fail "Running RSpec tests for #{directory} failed!" unless success
    end

    # Get the version set in the Dockerfile in the specified directory
    #
    def version
      puts PuppetDockerTools::Utilities.get_value_from_env('version', namespace: namespace, directory: directory, dockerfile: dockerfile)
    end
  end
end
