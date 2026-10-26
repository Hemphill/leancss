require "rails/generators"

module Leancss
  module Generators
    # bin/rails generate leancss:install
    class InstallGenerator < Rails::Generators::Base
      BOOTSTRAP_TAG = "v5.3.8".freeze
      CORE_STYLES_TAG = "v3.0.25".freeze

      source_root File.expand_path("templates", __dir__)
      desc "Adds config/initializers/leancss.rb, public and admin stylesheets compiled from Bootstrap's " \
           "and Core Styles 3's Sass with the app's own variables, and keeps the built files out of git."

      def copy_initializer
        template "leancss.rb", "config/initializers/leancss.rb"
      end

      def copy_stylesheets
        directory "stylesheets", "app/assets/stylesheets"
      end

      def add_sass
        gemfile = File.join(destination_root, "Gemfile")
        return if !File.exist?(gemfile) || File.read(gemfile).match?(/^\s*gem ["']sass-embedded["']/)

        gem "sass-embedded", "~> 1.93", comment: "Compiles the Sass that leancss builds (Dart Sass, no Node)"
      end

      def ignore_built_files
        return unless File.exist?(File.join(destination_root, ".gitignore"))
        return if File.read(File.join(destination_root, ".gitignore")).match?(%r{^/app/assets/builds/(\*|lean)})

        append_to_file ".gitignore", "\n# Built by leancss (bin/rails leancss:build)\n/app/assets/builds/lean\n"
      end

      def next_steps
        say "\nNext: bundle install, then link the builds in the layouts: " \
            "stylesheet_link_tag \"lean/public\" and \"lean/admin\"."
      end

      private

        def bootstrap_tag
          BOOTSTRAP_TAG
        end

        def core_styles_tag
          CORE_STYLES_TAG
        end

        # Apps using styler's layouts get its admin layout sorted into the admin build.
        def styler?
          Gem.loaded_specs.key?("styler")
        end
    end
  end
end
