require 'raven/processor'

module Raven
  module Processor
    class SanitizeData < Processor

      MASK = '********'
      FIELDS_RE = /(authorization|password|passwd|secret)/i
      VALUES_RE = /^\d{16}$/

      def apply(value, key=nil, visited=[], &block)
        if value.is_a?(Hash)
          return "{...}" if visited.include?(value.__id__)
          visited += [value.__id__]

          value.each.inject({}) do |memo, (k, v)|
            memo[k] = apply(v, k, visited, &block)
            memo
          end
        elsif value.is_a?(Array)
          return "[...]" if visited.include?(value.__id__)
          visited += [value.__id__]

          value.map do |value_|
            apply(value_, key, visited, &block)
          end
        else
          block.call(key, value)
        end
      end

      def sanitize(key, value)
        if !value.is_a?(String) || value.empty?
          value
        elsif VALUES_RE.match(clean_invalid_utf8_bytes(value)) or FIELDS_RE.match(key)
          MASK
        else
          clean_invalid_utf8_bytes(value)
        end
      end

      def process(data)
        apply(data) do |key, value|
          sanitize(key, value)
        end
      end

      private
      def clean_invalid_utf8_bytes(text)
        if RUBY_VERSION <= '1.8.7'
          text
        else
          text.encode(
            'UTF-8',
            'binary',
            :invalid => :replace,
            :undef => :replace,
            :replace => ''
          )
        end
      end
    end
  end
end
