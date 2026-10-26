require "fileutils"
require "open3"
require "pathname"
require "active_support/core_ext/object/blank"

module Leancss
  # A Sass library fetched from its git repo at a tag, like Bootstrap or Core
  # Styles 3, so an app's Sass can @import it without Node:
  #
  #   "bootstrap" => { git: "https://github.com/twbs/bootstrap.git", tag: "v5.3.8" }
  #
  # Only the scss folder is fetched (only: names others), into
  # tmp/cache/leancss/packages/<name>. That folder is on Sass's load path, so
  # "bootstrap/scss/functions" finds it, as it would in node_modules.
  class Package
    OPTIONS = %i[ git tag only ].freeze

    attr_reader :name, :git, :tag, :only

    # dir: the folder packages go in.
    def initialize(name, options, dir:)
      options = (options || {}).to_h.transform_keys(&:to_sym)
      unknown = options.keys - OPTIONS
      raise Error, "leancss package #{name}: unknown option #{unknown.first.inspect}" if unknown.any?
      raise Error, "leancss package #{name}: give its git: repo and the tag: to use" if options[:git].blank? || options[:tag].blank?

      @name = name.to_s
      @git = options[:git].to_s
      @tag = options[:tag].to_s
      @only = Array(options.fetch(:only, "scss")).map(&:to_s)
      @dir = Pathname(dir)
    end

    def path
      @dir.join(name)
    end

    # Changes when the settings change, so a new tag fetches again and rebuilds.
    def signature
      [ git, tag, only ].inspect
    end

    def fetched?
      marker.exist? && marker.read == signature
    end

    def fetch
      return if fetched?

      # Fetched beside the old copy and swapped in, so a failed fetch leaves it.
      partial = @dir.join(".#{name}.#{Process.pid}")
      FileUtils.rm_rf(partial)
      FileUtils.mkdir_p(@dir)
      run "git", "-c", "advice.detachedHead=false", "clone", "--quiet", "--depth", "1", "--branch", tag,
          "--filter=blob:none", "--sparse", git, partial.to_s
      run "git", "-C", partial.to_s, "sparse-checkout", "set", "--no-cone", *only.map { |folder| "/#{folder}/" }
      FileUtils.rm_rf(partial.join(".git"))
      File.write(partial.join(".leancss"), signature)
      FileUtils.rm_rf(path)
      FileUtils.mv(partial, path)
    ensure
      FileUtils.rm_rf(partial) if partial
    end

    private

      def marker
        path.join(".leancss")
      end

      def run(*command)
        output, status = Open3.capture2e({ "GIT_TERMINAL_PROMPT" => "0" }, *command)
        raise Error, "leancss package #{name}: couldn't fetch #{tag} from #{git}\n  #{output.strip}" unless status.success?
      rescue Errno::ENOENT
        raise Error, "leancss package #{name}: fetching it needs git"
      end
  end
end
