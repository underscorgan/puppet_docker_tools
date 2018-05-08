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

		def current_git_sha(directory = '.')
			Dir.chdir directory do
				`git rev-parse HEAD`.strip
			end
		end
	end
end
