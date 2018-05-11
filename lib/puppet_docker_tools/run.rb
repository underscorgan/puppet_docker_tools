require 'date'
require 'docker'
require 'rspec/core'
require 'time'
require 'puppet_docker_tools/utilities'
require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "spec", 'spec_helper.rb'))

class PuppetDockerTools
  module Run
    module_function

    def build(directory, repository: , namespace: ,no_cache: false)
      image_name = File.basename(directory)

      version = PuppetDockerTools::Utilities.get_value_from_env('version', namespace: namespace, directory: directory)
      path = "#{repository}/#{image_name}"
      puts "Building #{path}:latest"
      build_options = { 't' => "#{path}:latest" }
      if no_cache
        puts "Ignoring cache for #{path}"
        build_options['nocache'] = true
      end
      Docker::Image.build_from_dir(directory, build_options)

      if version
        puts "Building #{path}:#{version}"
        build_options = { 't' => "#{path}:#{version}" }
        Docker::Image.build_from_dir(directory, build_options)
      end
    end

    def lint(directory)
      PuppetDockerTools::Run.pull('lukasmartinelli/hadolint:latest')
      container = Docker::Container.create('Cmd' => ['/bin/sh', '-c', "hadolint --ignore DL3008 --ignore DL4000 --ignore DL4001 - "], 'Image' => 'lukasmartinelli/hadolint', 'OpenStdin' => true, 'StdinOnce' => true)
      container.tap(&:start).attach(stdin: "#{directory}/Dockerfile")
      container.wait
      exit_status = container.json['State']['ExitCode']
      unless exit_status == 0
        fail container.logs(stdout: true, stderr: true)
      end
    end

    def pull(image)
      if image.include?(':')
        puts "Pulling #{image}"
        PuppetDockerTools::Run.pull_single_tag(image)
      else
        puts "Pulling all tags for #{image}"
        PuppetDockerTools::Run.pull_all_tags(image)
      end
    end

    def pull_all_tags(image)
      Docker::Image.create('fromImage' => image)

      images = Docker::Image.all('filter' => image)
      images.each do |img|
        timestamp = PuppetDockerTools::Utilities.format_timestamp(img.info["Created"])
        puts "Pulled #{img.info["RepoTags"].join(', ')}, last updated #{timestamp}"
      end
    end

    def pull_single_tag(tag)
      image = Docker::Image.create('fromImage' => tag)
      timestamp = PuppetDockerTools::Utilities.format_timestamp(image.info["Created"])
      puts "Pulled #{image.info["RepoTags"].first}, last updated #{timestamp}"
    end

    def push(directory, repository: , namespace: )
      image_name = File.basename(directory)

      path = "#{repository}/#{image_name}"

      version = PuppetDockerTools::Utilities.get_value_from_label(path, value: 'version', namespace: namespace)

      unless version
        fail "No version specified in Dockerfile for #{path}"
      end

      puts "Pushing #{path}:#{version} to Docker Hub"
      exitstatus, _ = PuppetDockerTools::Utilities.push_to_dockerhub("#{path}:#{version}")
      unless exitstatus == 0
        puts "Pushing to #{path}:#{version} to dockerhub failed!"
        exit exitstatus
      end

      puts "Pushing #{path}:latest to Docker Hub"
      exitstatus, _ = PuppetDockerTools::Utilities.push_to_dockerhub("#{path}:latest")
      unless exitstatus == 0
        puts "Pushing #{path}:latest to dockerhub failed!"
        exit exitstatus
      end
    end


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

    def spec(directory)
      tests = Dir.glob("#{directory}/spec/*_spec.rb")
      test_files = tests.map { |test| File.basename(test, '.rb') }

      puts "Running RSpec tests from #{File.expand_path("#{directory}/spec")} (#{test_files.join ","}), this may take some time"
      RSpec::Core::Runner.run(tests, $stderr, $stdout)
    end

    def update_base_images(tags)
      tags.each do |tag|
        PuppetDockerTools::Run.pull(tag)
      end
    end

    def version(directory, namespace: )
      puts PuppetDockerTools::Utilities.get_value_from_env('version', namespace: namespace, directory: directory)
    end
  end
end
