require "set"

module Leancss
  # The words in an app's views, helpers and JavaScript, which decide which CSS
  # classes are kept. Every run of letters, digits, _ and - counts as a word,
  # so "btn btn-primary" in a class attribute, a helper or a JavaScript string
  # all keep .btn and .btn-primary. Runs with : / and . count too, for
  # class names like md:d-none and w-1/2.
  class Content
    # alert-<%= type %> in ERB, "alert-#{type}" in Ruby, and "alert-${type}" or
    # "alert-" + type in JavaScript.
    DYNAMIC = /([A-Za-z][\w-]*-)(?:<%=|#\{|\$\{|["']\s*\+)/

    attr_reader :files

    def initialize(files)
      @files = files.sort.uniq
    end

    def words
      @words ||= files.each_with_object(Set.new) do |file, words|
        text = read(file)
        text.scan(/[\w-]+/) { |word| words << word }
        text.scan(%r{[\w:/.-]*[:/][\w:/.-]*}) { |word| words << word }
      end
    end

    # Class names built in code, which trimming can't see: { "alert-" => [files] }.
    def dynamic_prefixes
      @dynamic_prefixes ||= files.each_with_object(Hash.new { |h, k| h[k] = [] }) do |file, prefixes|
        read(file).scan(DYNAMIC) { |(prefix)| prefixes[prefix] << file unless prefixes[prefix].include?(file) }
      end
    end

    private

      def read(file)
        File.read(file, encoding: "UTF-8", invalid: :replace, undef: :replace)
      end
  end
end
