require "fileutils"
require "pathname"
require "zlib"

module Leancss
  # One output file: its css: sources joined in order, trimmed against its
  # content files, minified, and written to <output>/<name>.css.
  class Build
    attr_reader :name, :sources, :content, :safelist, :output_path

    # sources: Source objects. content: a Content. safelist: words to keep even
    # though the content doesn't use them. trim: false only joins and minifies.
    # stamp_path: where to note the settings the file was built with.
    def initialize(name, sources:, content:, safelist: [], trim: true, output_path:, stamp_path:)
      @name = name.to_s
      @sources = sources
      @content = content
      @safelist = safelist
      @trim = trim
      @output_path = Pathname(output_path)
      @stamp_path = Pathname(stamp_path)
    end

    def trim?
      @trim
    end

    # Whether a source or content file changed since the file was written, or
    # the build settings changed.
    def stale?
      return true unless output_path.exist? && @stamp_path.exist? && File.read(@stamp_path) == stamp

      built_at = output_path.mtime
      inputs.any? { |file| File.mtime(file) > built_at }
    end

    # Writes the file and returns its Report.
    def run
      report = Report.new(self, original, trimmer.trim(original))
      FileUtils.mkdir_p(output_path.dirname)
      File.write(output_path, report.css)
      FileUtils.mkdir_p(@stamp_path.dirname)
      File.write(@stamp_path, stamp)
      report
    end

    # What run would do, without writing anything. Always trims, so the report
    # shows what trimming would remove even when it's off.
    def report
      Report.new(self, original, Trimmer.new(words).trim(original))
    end

    def words
      content.words | Trimmer::RUNTIME_CLASSES | safelist
    end

    private

      def original
        @original ||= sources.map(&:css).join("\n")
      end

      def trimmer
        Trimmer.new(trim? ? words : nil)
      end

      def inputs
        sources.flat_map(&:inputs).uniq.select(&:exist?) + content.files
      end

      # Changes when the settings change, so a new safelist rebuilds.
      def stamp
        [ VERSION, trim?, sources.map(&:signature), content.files, safelist.sort ].inspect
      end
  end

  # What a build did: sizes before and after, and what trimming removed.
  class Report
    attr_reader :build, :result

    def initialize(build, original, result)
      @build = build
      @original = original
      @result = result
    end

    def css
      result.css
    end

    def original_bytes
      @original.bytesize
    end

    def original_gzip
      gzip_size(@original)
    end

    def output_bytes
      css.bytesize
    end

    def output_gzip
      gzip_size(css)
    end

    # "public: 323 KB → 69 KB (40.1 KB → 12.5 KB gzipped), 2515 of 2984 rules removed"
    def summary
      line = "#{build.name}: #{kb(original_bytes)} → #{kb(output_bytes)} (#{kb(original_gzip)} → #{kb(output_gzip)} gzipped)"
      line += ", #{result.rules_removed} of #{result.rules} rules removed" if build.trim?
      line += ", not trimmed (trim: false)" unless build.trim?
      line
    end

    # The removed classes most likely to matter: ones starting with a prefix the
    # app builds class names from ("alert-#{type}"). { "alert-" => ["alert-danger", ...] }
    def suspects
      build.content.dynamic_prefixes.keys.each_with_object({}) do |prefix, found|
        names = result.removed.keys.select { |name| name.start_with?(prefix) }.sort
        found[prefix] = names if names.any?
      end
    end

    def details(limit: 40)
      lines = [ summary, "  #{build.content.files.size} content files, #{result.removed.size} classes and ids not used" ]
      lines << "  Most-used CSS that was removed (selectors per class):"
      result.removed.sort_by { |name, count| [ -count, name ] }.first(limit).each_slice(4) do |slice|
        lines << "    " + slice.map { |name, count| "#{name} (#{count})" }.join(", ")
      end
      if suspects.any?
        lines << "  Class names built in code; safelist the ones the app uses:"
        suspects.each do |prefix, names|
          files = build.content.dynamic_prefixes[prefix].map { |f| File.basename(f) }.join(", ")
          lines << "    #{prefix}… in #{files}: #{names.first(12).join(' ')}#{' …' if names.size > 12}"
        end
      end
      lines.join("\n")
    end

    private

      def gzip_size(text)
        Zlib::Deflate.deflate(text, Zlib::BEST_COMPRESSION).bytesize + 18
      end

      def kb(bytes)
        format("%.1f KB", bytes / 1024.0)
      end
  end
end
