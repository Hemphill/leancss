require "rails/railtie"
require "active_support/ordered_options"

module Leancss
  class Railtie < Rails::Railtie
    config.leancss = ActiveSupport::OrderedOptions.new
    # { "public" => { css: [...], content: [...], except: [...], safelist: [...], trim: true } }.
    # Without builds, each stylesheet whose name doesn't start with _ is built.
    config.leancss.builds = nil
    # Where class names are, for builds without content:. Defaults to
    # Configuration::DEFAULT_CONTENT plus the same folders in engines.
    config.leancss.content = nil
    # Class names to keep in every build.
    config.leancss.safelist = []
    # Rebuild stale files while the app runs: on each page request in
    # development, and once at boot in test. Production builds during
    # assets:precompile.
    config.leancss.auto_build = nil

    initializer "leancss.auto_build" do |app|
      auto_build = app.config.leancss.auto_build
      auto_build = Rails.env.local? if auto_build.nil?

      if auto_build && Rails.env.development?
        # First, so the file is written before Propshaft looks for changes.
        app.middleware.insert_before 0, AutoBuild
      elsif auto_build
        app.config.after_initialize { Leancss.build_stale(app) }
      end
    end

    rake_tasks do
      load File.expand_path("../tasks/leancss.rake", __dir__)
    end
  end

  # Rebuilds stale files before a page request in development.
  class AutoBuild
    LOCK = Mutex.new

    def initialize(app)
      @app = app
    end

    def call(env)
      unless env["PATH_INFO"].start_with?("/assets/")
        LOCK.synchronize do
          Leancss.build_stale.each { |report| Rails.logger.info("[leancss] #{report.summary}") }
        end
      end
      @app.call(env)
    end
  end
end
