require_relative "lib/leancss/version"

Gem::Specification.new do |spec|
  spec.name = "leancss"
  spec.version = Leancss::VERSION
  spec.authors = [ "Greg Hemphill" ]
  spec.email = [ "greg@webstop.com" ]

  spec.summary = "Makes a Rails app's CSS small by removing the rules its views don't use."
  spec.description = "Joins the stylesheets each layout needs (from the app, Sass, or a CDN), " \
                     "removes rules for classes the app's views never use, and minifies the rest. " \
                     "Pure Ruby: no Node."
  spec.homepage = "https://github.com/Hemphill/leancss"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.require_paths = [ "lib" ]

  # Parses CSS (also used by Rails' HTML sanitizer, so already in every app)
  spec.add_dependency "crass", "~> 1.0"
  spec.add_dependency "railties", ">= 7.1"
end
