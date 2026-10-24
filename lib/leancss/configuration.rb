require "pathname"
require "active_support/core_ext/object/blank"

module Leancss
  # Turns the settings in config/initializers/leancss.rb into Builds.
  class Configuration
    # Where an app's class names are, relative to its root.
    DEFAULT_CONTENT = %w[
      app/views/**/*
      app/helpers/**/*.rb
      app/components/**/*
      app/javascript/**/*.js
    ].freeze

    # The same folders in engines (gems with views, like styler's layouts).
    ENGINE_CONTENT = %w[ app/views/**/* app/helpers/**/*.rb app/components/**/* ].freeze

    OUTPUT_FOLDER = "lean".freeze

    attr_reader :root, :settings

    # settings: config.leancss (builds, content, safelist). root: the app's
    # root. engine_roots: the root folders of the app's engines.
    def initialize(settings, root:, engine_roots: [])
      @settings = settings
      @root = Pathname(root)
      @engine_roots = engine_roots.map { |path| Pathname(path) }
    end

    def stylesheets
      root.join("app/assets/stylesheets")
    end

    def output_dir
      root.join("app/assets/builds", OUTPUT_FOLDER)
    end

    def cache_dir
      root.join("tmp/cache/leancss")
    end

    def builds
      definitions.map do |name, options|
        options = (options || {}).transform_keys(&:to_sym)
        unknown = options.keys - %i[ css content except safelist trim ]
        raise Error, "leancss build #{name}: unknown option #{unknown.first.inspect}" if unknown.any?

        css = Array(options[:css])
        raise Error, "leancss build #{name}: list its CSS files in css:" if css.empty?

        Build.new(
          name,
          sources: css.map { |entry| Source.new(entry, stylesheets: stylesheets, cache: cache_dir, output_folder: OUTPUT_FOLDER) },
          content: Content.new(files(options[:content] || default_content) - files(Array(options[:except]))),
          safelist: Array(settings[:safelist]) + Array(options[:safelist]),
          trim: options.fetch(:trim, true),
          output_path: output_dir.join("#{name}.css"),
          stamp_path: cache_dir.join("#{name}.stamp")
        )
      end
    end

    # The files matching some globs. A glob is relative to the app's root, or to
    # a gem's folder when it starts with "gem:NAME/", like
    # "gem:styler/app/views/layouts/admin_cs3/**/*".
    def files(globs)
      Array(globs).flat_map do |glob|
        Dir.glob(expand(glob.to_s)).select { |path| File.file?(path) }
      end.uniq
    end

    private

      # The builds from the settings, or with none, one for each stylesheet whose
      # name doesn't start with _, named after it.
      def definitions
        return settings[:builds] if settings[:builds].present?

        Dir.glob(stylesheets.join("*.{css,scss,sass}")).sort.reject { |path| File.basename(path).start_with?("_") }.to_h do |path|
          [ File.basename(path, ".*"), { css: [ File.basename(path) ] } ]
        end
      end

      def default_content
        Array(settings[:content].presence || DEFAULT_CONTENT) + @engine_roots.flat_map { |engine| engine_files(engine) }
      end

      # An engine's views and helpers, less the pages it shows in its own
      # layout (letter_opener_web, Solid Errors, Action Mailbox's conductor),
      # which don't use the app's CSS. Views it renders in the app's pages, like
      # layouts and partials for the app to use, count.
      def engine_files(engine)
        views = engine.join("app/views")
        own = Dir.glob(views.join("layouts/*/**/*")).filter_map do |path|
          next if File.directory?(path) || File.basename(path).start_with?("_")

          folder = Pathname(path).relative_path_from(views.join("layouts")).each_filename.first
          folder if views.join(folder).directory?
        end.uniq
        skipped = own.flat_map { |folder| [ views.join(folder, "**/*"), views.join("layouts", folder, "**/*") ] }

        files(ENGINE_CONTENT.map { |glob| engine.join(glob).to_s }) - files(skipped.map(&:to_s))
      end

      def expand(glob)
        if (match = glob.match(%r{\Agem:([^/]+)/(.*)\z}))
          spec = Gem.loaded_specs[match[1]] or raise Error, "leancss: no gem named #{match[1]} is loaded (in #{glob})"
          File.join(spec.full_gem_path, match[2])
        else
          File.expand_path(glob, root)
        end
      end
  end
end
