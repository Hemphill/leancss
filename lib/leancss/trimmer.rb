require "crass"
require "set"

module Leancss
  # Removes the CSS rules an app doesn't use and minifies what's left.
  #
  # A selector is kept when every class and id it needs appears in the app's
  # words (see Content). Element and attribute selectors are always kept, and so
  # are classes inside :not(), :is(), :where() and :has(), since a page can match
  # those without using them. A rule is dropped when none of its selectors are
  # kept, and an @media or @supports block when none of its rules are.
  #
  # @keyframes, @font-face and custom properties are kept whole, and so are
  # comments starting with /*! (license notices).
  class Trimmer
    # Classes that Bootstrap's JavaScript adds and removes while the page runs,
    # so they never appear in views.
    RUNTIME_CLASSES = %w[
      show showing hiding fade collapse collapsing active disabled
      was-validated is-invalid is-valid
      modal-open modal-backdrop modal-static
      offcanvas-backdrop
      dropdown-menu-end dropstart dropend dropup
      tooltip tooltip-inner tooltip-arrow bs-tooltip-top bs-tooltip-end bs-tooltip-bottom bs-tooltip-start bs-tooltip-auto
      popover popover-header popover-body popover-arrow bs-popover-top bs-popover-end bs-popover-bottom bs-popover-start bs-popover-auto
      carousel-item-start carousel-item-end carousel-item-next carousel-item-prev
    ].freeze

    # Blocks whose contents are rules, so they're trimmed rule by rule.
    GROUPING_AT_RULES = %w[ media supports layer container ].freeze

    Result = Struct.new(:css, :rules, :rules_removed, :removed, keyword_init: true)

    # words: the Set of words used by the app. Pass nil to only minify.
    def initialize(words)
      @words = words
    end

    # Returns a Result: the trimmed CSS, the number of rules before and removed,
    # and a Hash of each missing class or id ("btn-group", "#map") and how many
    # selectors were removed for it.
    def trim(css)
      @rules = 0
      @rules_removed = 0
      @removed = Hash.new(0)
      output = write(Crass.parse(css, preserve_comments: true))
      Result.new(css: output, rules: @rules, rules_removed: @rules_removed, removed: @removed)
    end

    # The classes and ids a selector needs: ".nav .nav-link:not(.active)"
    # needs ["nav", "nav-link"].
    def self.needed_names(selector)
      plain = selector.gsub(/\[[^\]]*\]/, "")
      plain = plain.gsub(/:(?:not|is|where|has)\((?:[^()]|\([^()]*\))*\)/, "")
      plain.scan(/([.#])((?:\\[0-9a-fA-F]{1,6}\s?|\\.|[\w-])+)/).map do |kind, name|
        name = unescape(name)
        kind == "#" ? "##{name}" : name
      end
    end

    def self.unescape(name)
      name.gsub(/\\([0-9a-fA-F]{1,6})\s?/) { [ Regexp.last_match(1).hex ].pack("U") }.gsub(/\\(.)/, '\1')
    end

    # Splits "a, b:is(c, d)" into ["a", "b:is(c, d)"].
    def self.split_selectors(list)
      parts = []
      depth = 0
      current = +""
      list.each_char do |char|
        depth += 1 if char == "(" || char == "["
        depth -= 1 if char == ")" || char == "]"
        if char == "," && depth.zero?
          parts << current
          current = +""
        else
          current << char
        end
      end
      parts << current
      parts.map { |part| part.strip.gsub(/\s+/, " ") }.reject(&:empty?)
    end

    private

      def write(nodes)
        out = +""
        nodes.each do |node|
          case node[:node]
          when :style_rule then out << style_rule(node)
          when :at_rule then out << at_rule(node)
          when :comment then out << node[:raw] if node[:raw].start_with?("/*!")
          end
        end
        out
      end

      def style_rule(node)
        @rules += 1
        # The tokens' raw text keeps escapes (.md\:d-none); the selector's value doesn't.
        selectors = self.class.split_selectors(Crass::Parser.stringify(node[:selector][:tokens]))
        selectors = selectors.select { |selector| keep?(selector) } if @words
        if selectors.empty?
          @rules_removed += 1
          return ""
        end

        "#{selectors.join(',')}{#{declarations(node[:children])}}"
      end

      def keep?(selector)
        missing = self.class.needed_names(selector).reject do |name|
          @words.include?(name.delete_prefix("#"))
        end
        missing.each { |name| @removed[name] += 1 }
        missing.empty?
      end

      def declarations(children)
        children.filter_map do |child|
          next unless child[:node] == :property

          value = compact(child[:children]).strip
          "#{child[:name]}:#{value}#{'!important' if child[:important]}"
        end.join(";")
      end

      def at_rule(node)
        prelude = compact(node[:prelude]).strip
        head = prelude.empty? ? "@#{node[:name]}" : "@#{node[:name]} #{prelude}"
        if GROUPING_AT_RULES.include?(node[:name]) && node[:block]
          inner = write(Crass::Parser.parse_rules(node[:block], preserve_comments: true))
          inner.empty? ? "" : "#{head}{#{inner}}"
        elsif node[:block]
          "#{head}{#{compact(node[:block]).strip}}"
        else
          "#{head};"
        end
      end

      # Turns tokens back into CSS with each run of whitespace as one space.
      # Strings are single tokens, so the spaces inside them stay.
      def compact(tokens)
        Crass::Parser.stringify(squash(Array(tokens)))
      end

      def squash(tokens)
        tokens.map do |token|
          if token[:node] == :whitespace
            { node: :whitespace, raw: " " }
          elsif token[:value].is_a?(Array)
            token.merge(value: squash(token[:value]))
          else
            token
          end
        end
      end
  end
end
