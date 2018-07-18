# frozen_string_literal: true

module Capapi
  class ListObject < CapapiObject
    include Enumerable
    include Capapi::APIOperations::List
    include Capapi::APIOperations::Request
    OBJECT_NAME = "list".freeze

    # This accessor allows a `ListObject` to inherit various filters that were
    # given to a predecessor. This allows for things like consistent limits,
    # expansions, and predicates as a user pages through resources.
    attr_accessor :filters

    attr_accessor :nested_object_name

    def self.construct_from(values, opts = {}, nested_object_name = nil)
      values = Capapi::Util.symbolize_names(values)
      
      # work around protected #initialize_from for now
      list = new(values[:id])
      list.nested_object_name = nested_object_name
      list.send(:initialize_from, values, opts)
    end

    # An empty list object. This is returned from +next+ when we know that
    # there isn't a next page in order to replicate the behavior of the API
    # when it attempts to return a page beyond the last.
    def self.empty_list(opts = {})
      ListObject.construct_from({ results: [] }, opts)
    end

    def initialize(*args)
      super
      self.filters = {}
    end

    def [](k)
      case k
      when String, Symbol
        super
      else
        raise ArgumentError, "You tried to access the #{k.inspect} index, but ListObject types only support String keys. (HINT: List calls return an object with a 'results' (which is the results array). You likely want to call #results[#{k.inspect}])"
      end
    end

    # Iterates through each resource in the page represented by the current
    # `ListObject`.
    #
    # Note that this method makes no effort to fetch a new page when it gets to
    # the end of the current page's resources. See also +auto_paging_each+.
    def each(&blk)
      results.each(&blk)
    end

    # Iterates through each resource in all pages, making additional fetches to
    # the API as necessary.
    #
    # Note that this method will make as many API calls as necessary to fetch
    # all resources. For more granular control, please see +each+ and
    # +next_page+.
    def auto_paging_each(&blk)
      return enum_for(:auto_paging_each) unless block_given?

      page = self
      loop do
        page.each(&blk)
        page = page.next_page
        break if page.empty?
      end
    end

    # Returns true if the page object contains no elements.
    def empty?
      results.empty?
    end

    def retrieve(id, opts = {})
      id, retrieve_params = Util.normalize_id(id)
      resp, opts = request(:get, "#{resource_url}#{CGI.escape(id)}", retrieve_params, opts)
      Util.convert_to_capapi_object(resp.results, opts)
    end

    # Fetches the next page in the resource list (if there is one).
    #
    # This method will try to respect the limit of the current page. If none
    # was given, the default limit will be fetched again.
    def next_page(params = {}, opts = {})
      do_page(params, opts, self.next)
    end

    # Fetches the previous page in the resource list (if there is one).
    #
    # This method will try to respect the limit of the current page. If none
    # was given, the default limit will be fetched again.
    def previous_page(params = {}, opts = {})
      do_page(params, opts, previous)
    end

    def resource_url
      url ||
        raise(ArgumentError, "List object does not contain a 'url' field.")
    end

    private

    def do_page(params, opts, url)
      return self.class.empty_list(opts) unless url
      url = url[0..Capapi.api_base.length-1] == Capapi.api_base ?
              url[Capapi.api_base.length..-1] : url
      u = URI.parse(url)
      params = filters.merge(Hash[URI.decode_www_form(u.query)]).merge(params)
      list(params, opts, u.path, nested_object_name)
    end
  end
end
