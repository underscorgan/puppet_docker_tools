class PuppetDockerTools
  module Utilities
    module Dockerfile
      module_function

      def get_value_from_dockerfile(key, directory: '.', dockerfile: '')
        if dockerfile.empty?
          dockerfile = File.read("#{directory}/Dockerfile")
        end
        dockerfile[/^#{key.upcase} (.*$)/, 1]
      end

      def get_value_from_base_image(label, directory: '.', dockerfile: '')
        base_image = get_value_from_dockerfile('from', directory: directory, dockerfile: dockerfile).split(':').first.split('/').last
        get_value_from_env(label, directory: "#{directory}/../#{base_image}")
      end

      def get_value_from_variable(variable, directory: '.', dockerfile: '')
        if dockerfile.empty?
          dockerfile = File.read("#{directory}/Dockerfile")
        end
        # get rid of the leading $ for the variable
        variable[0] = ''
        dockerfile[/#{variable}=(["a-zA-Z0-9\.]+)/, 1]
      end

      def get_value_from_env(label, directory: '.')
        text = File.read("#{directory}/Dockerfile")
        value = text.scan(/org\.label-schema\.(.+)=(.+) \\?/).to_h[label]
        # expand out environment variables
        value = get_value_from_variable(value, directory: directory, dockerfile: text) if value.start_with?('$')
        # check in higher-level image if we didn't find it defined in this docker file
        value = get_value_from_base_image(label, directory: directory) if value.nil?
        value.gsub(/\A"|"\Z/, '')
      end

    end
  end
end
