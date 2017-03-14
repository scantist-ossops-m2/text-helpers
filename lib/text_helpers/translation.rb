require "i18n"
require "active_support/core_ext/string/output_safety"
require "redcarpet"

module TextHelpers

  class ExternalLinks < Redcarpet::Render::HTML

    PROTOCOL_MATCHER = /\Ahttp/.freeze

    def link(link, title, content)
      attributes = [
        ("href=\"#{link}\"" if link),
        ("title=\"#{title}\"" if title),
        ("target=\"_blank\"" if link =~ PROTOCOL_MATCHER),
      ]

      "<a #{attributes.compact.join(" ")}>#{content}</a>"
    end

  end

  module Translation

    ORPHAN_MATCHER = /\s(?![^<]*>)(\S+\s*<\/(?:p|li)>)/.freeze

    # Public: Get the I18n localized text for the passed key.
    #
    # key     - The desired I18n lookup key.
    # options - A Hash of options to forward to the `I18n.t` lookup.
    #           :smart - Whether or not to apply smart quoting to the output.
    #                    Defaults to true.
    #
    # Returns a String resulting from the I18n lookup.
    def text(key, options = {})
      options = html_safe_options(options)
      text = I18n.t(key, {
        scope: self.translation_scope,
        default: "!#{key}!"
      }.merge(options)).strip

      interpolation_options = options.dup
      interpolation_options[:cascade] = true unless interpolation_options.has_key?(:cascade)

      # Interpolate any keypaths (e.g., `!some.lookup.path/key!`) found in the text.
      while text =~ /!([\w._\/]+)!/ do
        text = text.gsub(/!([\w._\/]+)!/) { |match| I18n.t($1, interpolation_options) }
      end

      text = smartify(text) if options.fetch(:smart, true)
      text.html_safe
    end

    # Public: Get an HTML representation of the rendered markdown for the passed I18n key.
    #
    # key     - The desired I18n lookup key.
    # options - A Hash of options to pass through to the lookup.
    #           :inline  - A special option that will remove the enclosing <p>
    #                      tags when set to true.
    #           :orphans - A special option that will prevent the insertion of
    #                      non-breaking space characters at the end of each
    #                      paragraph when set to true.
    #
    # Returns a String containing the localized text rendered via Markdown
    def html(key, options = {})
      rendered = markdown(text(key, options.merge(smart: false)))

      rendered = options[:orphans] ? rendered : rendered.gsub(ORPHAN_MATCHER, '&nbsp;\1')
      rendered = rendered.gsub(/<\/?p>/, '') if options[:inline]
      rendered.html_safe
    end

    protected

    # Protected: Render the passed text as HTML via Markdown.
    #
    # text - A String representing the text which should be rendered to HTML.
    #
    # Returns a String.
    def markdown(text)
      @renderer ||= Redcarpet::Markdown.new(ExternalLinks, no_intra_emphasis: true)
      smartify(@renderer.render(text))
    end

    # Protected: Auto-apply smart quotes and to the passed text.
    #
    # text - A String which should be passed through the SmartyPants renderer.
    #
    # Returns a String.
    def smartify(text)
      Redcarpet::Render::SmartyPants.render(text)
    end

    # Protected: The proper scope for I18n translation.
    #
    # Must be implemented by any classes which include this module.
    #
    # Raises NotImplementedError.
    def translation_scope
      raise NotImplementedError, "must implement a public method `translation_scope` to determine I18n scope"
    end

    # Protected: Convert all passed in arguments into html-safe strings
    #
    # hash - a set of key-value pairs, which converts the second argument into an html-safe string
    #
    # Returns a hash
    def html_safe_options(hash)
      hash.inject({}) do |result, (key, value)|
        result[key] = case value
          when String
            ERB::Util.h(value)
          else
            value
          end

        result
      end
    end
  end
end
