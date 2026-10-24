require "rails/generators"

module Leancss
  module Generators
    # bin/rails generate leancss:install
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Adds config/initializers/leancss.rb and keeps the built files out of git."

      def copy_initializer
        template "leancss.rb", "config/initializers/leancss.rb"
      end

      def ignore_built_files
        return unless File.exist?(File.join(destination_root, ".gitignore"))
        return if File.read(File.join(destination_root, ".gitignore")).match?(%r{^/app/assets/builds/(\*|lean)})

        append_to_file ".gitignore", "\n# Built by leancss (bin/rails leancss:build)\n/app/assets/builds/lean\n"
      end
    end
  end
end
