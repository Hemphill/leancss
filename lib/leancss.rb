require "leancss/version"
require "leancss/trimmer"
require "leancss/content"
require "leancss/source"
require "leancss/build"
require "leancss/configuration"

# Makes a Rails app's CSS small: joins the stylesheets each layout needs,
# removes the rules for classes its views never use, and minifies the rest.
module Leancss
  class Error < StandardError; end

  # The app's builds, from config/initializers/leancss.rb.
  def self.configuration(app = Rails.application)
    engines = Rails::Engine.subclasses.map(&:instance).reject { |engine| engine.is_a?(Rails::Application) }
    Configuration.new(app.config.leancss, root: app.root, engine_roots: engines.map(&:root))
  end

  # Builds whatever changed since it was last built. Returns the Reports.
  def self.build_stale(app = Rails.application)
    configuration(app).builds.select(&:stale?).map(&:run)
  end
end

require "leancss/railtie" if defined?(Rails::Railtie)
