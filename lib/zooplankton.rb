require "rails"

require "zooplankton/version"

module Zooplankton
  class << self
    def path_template_for(helper_name, query_params={}, supplied_params=nil)
      build_template(:path, helper_name, *parse_params(query_params, supplied_params))
    end

    def url_template_for(helper_name, query_params={}, supplied_params=nil)
      build_template(:url, helper_name, *parse_params(query_params, supplied_params))
    end

    private

    def parse_params(*args)
      if args.first.respond_to?(:to_h) && !args.first.is_a?(Array)
        query_params = []
        supplied_params = args.first.to_h
      else
        query_params = Array(args.shift)
        supplied_params = args.first || {}
      end

      [query_params, supplied_params]
    end

    def build_template(type, helper_name, query_params, supplied_params)
      return unless named_routes.names.include?(helper_name)

      escaped_template_without_query_params = expand_helper(helper_name, type, supplied_params)
      escaped_template = append_query_params(escaped_template_without_query_params, query_params, supplied_params)

      unescape_template(escaped_template)
    end

    def append_query_params(template, query_params, supplied_params)
      return template unless query_params.any?

      supplied_query_params = query_params & supplied_params.keys
      supplied_query_string = ''

      if supplied_query_params.any?
        continuation_or_expansion = '&'

        supplied_query_string << '?'

        supplied_query_string << supplied_query_params.map do |key|
          "#{key.to_s}=#{URI.encode(supplied_params[key].to_s)}"
        end.join('&')

        query_params = query_params - supplied_query_params
      else
        continuation_or_expansion = '?'
      end

      "#{template}#{supplied_query_string}{#{continuation_or_expansion}#{query_params.join(',')}}"
    end

    def expand_helper(helper_name, path_or_url, params)
      helper_method = "#{helper_name}_#{path_or_url}"

      url_helpers.send(helper_method, *templated_supplied_params_for(helper_name, params))
    end

    def named_routes
      Rails.application.routes.named_routes
    end

    def route_object_for(helper_name)
      named_routes.routes[helper_name]
    end

    def templated_supplied_params_for(helper_name, params)
      route_object_for(helper_name).required_parts.map do |required_part|
        params.fetch(required_part) { "{#{required_part}}" }
      end
    end

    def unescape_template(template)
      CGI.unescape(template)
    end

    def url_helpers
      Rails.application.routes.url_helpers
    end
  end
end
