require 'date'
require 'docker'
require 'rspec/core'
require 'time'
require 'puppet_docker_tools/utilities'
require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "spec", 'spec_helper.rb'))

class PuppetDockerTools
  class Runner
    attr_accessor :directory, :repository, :namespace

    def initialize(directory: , repository: , namespace: )
      @directory = directory
      @repository = repository
      @namespace = namespace
    end

    # Build a docker image from a directory
    #
    # @param no_cache Whether or not to use existing layer caches when building
    #        this image. Defaults to using the cache (no_cache = false).
    def build(no_cache: false)
      image_name = File.basename(directory)
      version = PuppetDockerTools::Utilities.get_value_from_env('version', namespace: namespace, directory: directory)
      path = "#{repository}/#{image_name}"
      puts "Building #{path}:latest"

      # 't' in the build_options sets the tag for the image we're building
      build_options = { 't' => "#{path}:latest" }
      if no_cache
        puts "Ignoring cache for #{path}"
        build_options['nocache'] = true
      end
      Docker::Image.build_from_dir(directory, build_options)

      if version
        puts "Building #{path}:#{version}"

        # 't' in the build_options sets the tag for the image we're building
        build_options = { 't' => "#{path}:#{version}" }
        Docker::Image.build_from_dir(directory, build_options)
      end
    end

    # Run hadolint on the Dockerfile in the specified directory. Hadolint is a
    # linter for dockerfiles that also validates inline bash with shellcheck.
    # For more info, see the github repo (https://github.com/hadolint/hadolint)
    #
    def lint
      hadolint_container = 'hadolint/hadolint'
      # make sure we have the container locally
      PuppetDockerTools::Utilities.pull("#{hadolint_container}:latest")
      container = Docker::Container.create('Cmd' => ['/bin/sh', '-c', "hadolint --ignore DL3008 --ignore DL4000 --ignore DL4001 - "], 'Image' => hadolint_container, 'OpenStdin' => true, 'StdinOnce' => true)
      # This container.tap startes the container created above, and passes directory/Dockerfile to the container
      container.tap(&:start).attach(stdin: "#{directory}/#{PuppetDockerTools::DOCKERFILE}")
      # Wait for the run to finish
      container.wait
      exit_status = container.json['State']['ExitCode']
      unless exit_status == 0
        fail container.logs(stdout: true, stderr: true)
      end
    end

    # Push an image to hub.docker.com
    #
    def push
      image_name = File.basename(directory)
      path = "#{repository}/#{image_name}"
      version = PuppetDockerTools::Utilities.get_value_from_label(path, value: 'version', namespace: namespace)

      # We always want to push a versioned label in addition to the latest label
      unless version
        fail "No version specified in #{PuppetDockerTools::DOCKERFILE} for #{path}"
      end

      puts "Pushing #{path}:#{version} to Docker Hub"
      exitstatus, _ = PuppetDockerTools::Utilities.push_to_dockerhub("#{path}:#{version}")
      unless exitstatus == 0
        fail "Pushing #{path}:#{version} to dockerhub failed!"
      end

      puts "Pushing #{path}:latest to Docker Hub"
      exitstatus, _ = PuppetDockerTools::Utilities.push_to_dockerhub("#{path}:latest")
      unless exitstatus == 0
        fail "Pushing #{path}:latest to dockerhub failed!"
      end
    end

    # Update vcs-ref and build-date labels in the Dockerfile
    #
    def rev_labels
      dockerfile = File.join(directory, PuppetDockerTools::DOCKERFILE)

      unless File.exist? dockerfile
        fail "File #{dockerfile} doesn't exist."
      end

      values_to_update = {
        "#{namespace}.vcs-ref" => PuppetDockerTools::Utilities.current_git_sha(directory),
        "#{namespace}.build-date" => Time.now.utc.iso8601
      }

      text = File.read(dockerfile)
      values_to_update.each do |key, value|
        original = text.clone
        text = text.gsub(/#{key}=\"[a-z0-9A-Z\-:]*\"/, "#{key}=\"#{value}\"")
        puts "Updating #{key} in #{dockerfile}" unless original == text
      end

      File.open(dockerfile, 'w') { |file| file.puts text }
    end

    # Run spec tests
    #
    def spec
      tests = Dir.glob("#{directory}/spec/*_spec.rb")
      test_files = tests.map { |test| File.basename(test, '.rb') }

      puts "Running RSpec tests from #{File.expand_path("#{directory}/spec")} (#{test_files.join ","}), this may take some time"
      RSpec::Core::Runner.run(tests, $stderr, $stdout)
    end

    # Get the version set in the Dockerfile in the specified directory
    #
    def version
      puts PuppetDockerTools::Utilities.get_value_from_env('version', namespace: namespace, directory: directory)
    end
  end
end
