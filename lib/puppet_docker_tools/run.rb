require 'date'
require 'docker'
require 'rspec/core'
require 'time'
require 'puppet_docker_tools/utilities'
require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "spec", 'spec_helper.rb'))

class PuppetDockerTools
  module Run
    module_function

    # Build a docker image from a directory
    #
    # @param directory The directory containing the Dockerfile you're building
    #        the image from
    # @param repository The repository this image will be pushed to
    # @param namespace The namespace for the version label in the dockerfile
    # @param no_cache Whether or not to use existing layer caches when building
    #        this image. Defaults to using the cache (no_cache = false).
    def build(directory, repository: , namespace: ,no_cache: false)
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

    # Run hadolint on the Dockerfile in the specified directory
    #
    # @param directory
    def lint(directory)
      hadolint_container = 'lukasmartinelli/hadolint'
      # make sure we have the container locally
      PuppetDockerTools::Run.pull("#{hadolint_container}:latest")
      container = Docker::Container.create('Cmd' => ['/bin/sh', '-c', "hadolint --ignore DL3008 --ignore DL4000 --ignore DL4001 - "], 'Image' => hadolint_container, 'OpenStdin' => true, 'StdinOnce' => true)
      # This container.tap startes the container created above, and passes directory/Dockerfile to the container
      container.tap(&:start).attach(stdin: "#{directory}/Dockerfile")
      # Wait for the run to finish
      container.wait
      exit_status = container.json['State']['ExitCode']
      unless exit_status == 0
        fail container.logs(stdout: true, stderr: true)
      end
    end

    # Pull a docker image
    #
    # @param image The image to pull. If the image does not include the tag to
    #        pull, it will pull all tags for that image
    def pull(image)
      if image.include?(':')
        puts "Pulling #{image}"
        PuppetDockerTools::Run.pull_single_tag(image)
      else
        puts "Pulling all tags for #{image}"
        PuppetDockerTools::Run.pull_all_tags(image)
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

    # Push an image to hub.docker.com
    #
    # @param directory The directory containing the Dockerfile for the image you
    #        want to push
    # @param repository The repository this will be pushed to
    # @param namespace The namespace for the version label in the dockerfile
    def push(directory, repository: , namespace: )
      image_name = File.basename(directory)
      path = "#{repository}/#{image_name}"
      version = PuppetDockerTools::Utilities.get_value_from_label(path, value: 'version', namespace: namespace)

      # We always want to push a versioned label in addition to the latest label
      unless version
        fail "No version specified in Dockerfile for #{path}"
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
    # @param directory The directory containing the Dockerfile to update
    # @param namespace The namespace for the labels
    def rev_labels(directory, namespace: )
      dockerfile = File.join(directory, 'Dockerfile')

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
    # @param directory The directory containing image build info. This command
    #        looks for spec tests under "#{directory}/spec/*_spec.rb
    def spec(directory)
      tests = Dir.glob("#{directory}/spec/*_spec.rb")
      test_files = tests.map { |test| File.basename(test, '.rb') }

      puts "Running RSpec tests from #{File.expand_path("#{directory}/spec")} (#{test_files.join ","}), this may take some time"
      RSpec::Core::Runner.run(tests, $stderr, $stdout)
    end

    # Pull the specified tags
    #
    # @param tags [Array] A list of tags to pull, e.g. ['centos:7', 'ubuntu:16.04']
    def update_base_images(tags)
      tags.each do |tag|
        PuppetDockerTools::Run.pull(tag)
      end
    end

    # Get the version set in the Dockerfile in the specified directory
    #
    # @param directory
    # @param namespace The namespace for the version label
    def version(directory, namespace: )
      puts PuppetDockerTools::Utilities.get_value_from_env('version', namespace: namespace, directory: directory)
    end
  end
end
