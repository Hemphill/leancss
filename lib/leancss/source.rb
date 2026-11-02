require "digest"
require "fileutils"
require "net/http"
require "pathname"
require "uri"

module Leancss
  # One entry in a build's css: list:
  #
  # * a URL, like a framework's file on a CDN. Downloaded once and cached, so
  #   use a URL with a version in it. Relative url()s in it are made absolute.
  # * a .css file, relative to app/assets/stylesheets (or an absolute path).
  # * a .scss or .sass file, compiled with Dart Sass (add the sass-embedded gem).
  #   It can @import the app's other stylesheets and the packages.
  class Source
    attr_reader :entry

    # stylesheets: the app's app/assets/stylesheets. cache: where downloads are
    # kept. output_folder: the built file's folder inside app/assets/builds
    # ("lean"), for fixing relative url()s. packages: Packages for Sass to use.
    def initialize(entry, stylesheets:, cache:, output_folder:, packages: [])
      @entry = entry.to_s
      @stylesheets = Pathname(stylesheets)
      @cache = Pathname(cache)
      @output_folder = Pathname(output_folder)
      @packages = packages
    end

    def url?
      entry.match?(%r{\Ahttps?://})
    end

    def sass?
      !url? && %w[ .scss .sass ].include?(path.extname)
    end

    # The files whose changes mean a rebuild: the file itself, and for Sass, the
    # stylesheets it could @import, plain .css files included.
    def inputs
      return [] if url?
      return [ path ] unless sass?

      [ path ] + Dir.glob(@stylesheets.join("**/*.{scss,sass,css}")).map { |file| Pathname(file) }
    end

    # Changes when the source's settings change, like a package's tag.
    def signature
      sass? ? [ entry, @packages.map(&:signature) ] : entry
    end

    # The file this source reads (the cached download, for a URL).
    def path
      url? ? @cache.join("#{Digest::SHA256.hexdigest(entry)[0, 16]}-#{File.basename(URI(entry).path)}") : @stylesheets.join(entry)
    end

    def css
      if url?
        download unless path.exist?
        absolute_urls(File.read(path), entry)
      elsif !path.exist?
        raise Error, "#{entry} isn't in #{@stylesheets}"
      elsif sass?
        relative_urls(compile_sass)
      else
        relative_urls(File.read(path))
      end
    end

    private

      URL = /url\(\s*(['"]?)(?!data:|https?:|\/\/|#|\/)([^'")]+)\1\s*\)/

      def download(uri = URI(entry), redirects = 3)
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPRedirection) && redirects.positive?
          return download(URI.join(uri, response["location"]), redirects - 1)
        end
        raise Error, "couldn't download #{entry} (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

        FileUtils.mkdir_p(path.dirname)
        File.binwrite(path, response.body)
      end

      def absolute_urls(css, base)
        css.gsub(URL) { "url(#{Regexp.last_match(1)}#{URI.join(base, Regexp.last_match(2))}#{Regexp.last_match(1)})" }
      end

      # Propshaft reads url()s relative to the CSS file's place among the assets
      # ("lite.css" → "", "lean/public.css" → "lean"), so point them from the
      # built file's folder back to the original's.
      def relative_urls(css)
        return css if Pathname(entry).absolute?

        back = Pathname(File.dirname(entry)).relative_path_from(@output_folder)
        css.gsub(URL) do
          quote, url = Regexp.last_match(1), Regexp.last_match(2)
          "url(#{quote}#{back.join(url).cleanpath}#{quote})"
        end
      end

      def compile_sass
        begin
          require "sass-embedded"
        rescue LoadError
          raise Error, "#{entry} is Sass: add the sass-embedded gem to compile it"
        end

        @packages.each(&:fetch)
        load_paths = [ @stylesheets, *@packages.map { |package| package.path.dirname } ].uniq.map(&:to_s)
        begin
          # Bootstrap 5 and CS3 still use @import, so don't warn about it on every
          # build. quiet_deps keeps the packages' own deprecations quiet too.
          Sass.compile(path.to_s, load_paths: load_paths, style: :expanded,
                                  quiet_deps: true, silence_deprecations: %w[ import ]).css
        rescue Sass::CompileError => error
          where = error.span && "#{File.basename(error.span.url.to_s)} line #{error.span.start.line + 1}: #{error.span.text}"
          raise Error, [ "#{entry}: #{error.message}", where ].compact.join("\n  ")
        end
      end
  end
end
