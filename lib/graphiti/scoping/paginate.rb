module Graphiti
  class Scoping::Paginate < Scoping::Base
    DEFAULT_PAGE_SIZE = 20
    PARAMS = [:number, :size, :offset, :before, :after]

    def apply
      if size > resource.max_page_size
        raise Graphiti::Errors::UnsupportedPageSize
          .new(size, resource.max_page_size)
      elsif requested? && @opts[:sideload_parent_length].to_i > 1
        raise Graphiti::Errors::UnsupportedPagination
      else
        super
      end
    end

    # We want to apply this logic unless we've explicitly received the
    # +default: false+ option. In that case, only apply if pagination
    # was explicitly specified in the request.
    #
    # @return [Boolean] should we apply this logic?
    def apply?
      if @opts[:default_paginate] == false
        requested?
      else
        true
      end
    end

    # @return [Proc, Nil] the custom pagination proc
    def custom_scope
      resource.pagination
    end

    # Apply default pagination proc via the Resource adapter
    def apply_standard_scope
      arity = resource.adapter.method(:paginate)

      if arity == 4 # backwards-compat
        resource.adapter.paginate(@scope, number, size)
      else
        resource.adapter.paginate(@scope, number, size, offset)
      end
    end

    # Apply the custom pagination proc
    def apply_custom_scope
      resource.instance_exec \
        @scope,
        number,
        size,
        resource.context,
        offset,
        &custom_scope
    end

    private

    def requested?
      ![page_param[:size], page_param[:number]].all?(&:nil?)
    end

    def page_param
      @page_param ||= (query_hash[:page] || {})
    end

    def offset
      offset = 0
      if (value = page_param[:offset])
        offset = value.to_i
      end

      if before_cursor&.key?(:offset)
        offset = before_cursor[:offset] - (size * number) - 2
        offset = 0 if offset.negative?
      end

      if after_cursor&.key?(:offset)
        offset = after_cursor[:offset]
      end

      offset
    end

    def after_cursor
      @after_cursor ||= parse_cursor(:after)
    end

    def before_cursor
      @before_cursor ||= parse_cursor(:before)
    end

    def number
      (page_param[:number] || 1).to_i
    end

    def size
      (page_param[:size] || resource.default_page_size).to_i
    end

    def parse_cursor(key)
      if (value = page_param[key])
        JSON.parse(Base64.decode64(value)).deep_symbolize_keys
      end
    end
  end
end
