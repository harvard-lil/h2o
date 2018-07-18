# frozen_string_literal: true

module Capapi
  class CapapiObject
    include Enumerable

    def initialize(id = nil, opts = {})
      id, @retrieve_params = Util.normalize_id(id)
      @opts = Util.normalize_opts(opts)
      @values = {}
      @values[:id] = id if id
    end

    def self.construct_from(values, opts = {})
      values = Capapi::Util.symbolize_names(values)
      
      # work around protected #initialize_from for now
      new(values[:id]).send(:initialize_from, values, opts)
    end

    # Determines the equality of two Capapi objects. Capapi objects are
    # considered to be equal if they have the same set of values and each one
    # of those values is the same.
    def ==(other)
      other.is_a?(CapapiObject) && @values == other.instance_variable_get(:@values)
    end

    def to_s(*_args)
      JSON.pretty_generate(to_hash)
    end

    def inspect
      id_string = respond_to?(:id) && !id.nil? ? " id=#{id}" : ""
      "#<#{self.class}:0x#{object_id.to_s(16)}#{id_string}> JSON: " + JSON.pretty_generate(@values)
    end

    # Mass assigns attributes on the model.
    #
    # This is a version of +update_attributes+ that takes some extra options
    # for internal use.
    #
    # ==== Attributes
    #
    # * +values+ - Hash of values to use to update the current attributes of
    #   the object.
    # * +opts+ - Options for +CapapiObject+ like an API key that will be reused
    #   on subsequent API calls.
    def update_attributes(values, opts = {}, object_name = nil)
      values.each do |k, v|
        add_accessors([k], values) unless metaclass.method_defined?(k.to_sym)
        name = object_name ?
               object_name :
                 (k == :results ?
                    nested_object_name :
                    k.to_s.singularize)
        @values[k] = Util.convert_to_capapi_object(v, opts, name)
      end
    end

    def [](k)
      @values[k.to_sym]
    end

    def keys
      @values.keys
    end

    def values
      @values.values
    end

    def to_json(*_a)
      JSON.generate(@values)
    end

    def as_json(*a)
      @values.as_json(*a)
    end

    def to_hash
      maybe_to_hash = lambda do |value|
        value && value.respond_to?(:to_hash) ? value.to_hash : value
      end

      @values.each_with_object({}) do |(key, value), acc|
        acc[key] = case value
                   when Array
                     value.map(&maybe_to_hash)
                   else
                     maybe_to_hash.call(value)
                   end
      end
    end

    def each(&blk)
      @values.each(&blk)
    end

    # Implements custom encoding for Ruby's Marshal. The data produced by this
    # method should be comprehendable by #marshal_load.
    #
    # This allows us to remove certain features that cannot or should not be
    # serialized.
    def marshal_dump
      # The CapapiClient instance in @opts is not serializable and is not
      # really a property of the CapapiObject, so we exclude it when
      # dumping
      opts = @opts.clone
      opts.delete(:client)
      [@values, opts]
    end

    # Implements custom decoding for Ruby's Marshal. Consumes data that's
    # produced by #marshal_dump.
    def marshal_load(data)
      values, opts = data
      initialize(values[:id])
      initialize_from(values, opts)
    end

    protected

    def metaclass
      class << self; self; end
    end

    def remove_accessors(keys)
      metaclass.instance_eval do
        keys.each do |k|
          # Remove methods for the accessor's reader and writer.
          [k, :"#{k}=", :"#{k}?"].each do |method_name|
            remove_method(method_name) if method_defined?(method_name)
          end
        end
      end
    end

    def add_accessors(keys, values)
      metaclass.instance_eval do
        keys.each do |k|
          if k == :method
            # Object#method is a built-in Ruby method that accepts a symbol
            # and returns the corresponding Method object. Because the API may
            # also use `method` as a field name, we check the arity of *args
            # to decide whether to act as a getter or call the parent method.
            define_method(k) { |*args| args.empty? ? @values[k] : super(*args) }
          else
            define_method(k) { @values[k] }
          end

          define_method(:"#{k}=") do |v|
            if v == ""
              raise ArgumentError, "You cannot set #{k} to an empty string. " \
                "We interpret empty strings as nil in requests. " \
                "You may set (object).#{k} = nil to delete the property."
            end
            @values[k] = Util.convert_to_capapi_object(v, @opts, k.to_s.singularize)
          end

          if [FalseClass, TrueClass].include?(values[k].class)
            define_method(:"#{k}?") { @values[k] }
          end
        end
      end
    end

    def method_missing(name, *args)
      if name.to_s.end_with?("=")
        attr = name.to_s[0...-1].to_sym

        # Pull out the assigned value. This is only used in the case of a
        # boolean value to add a question mark accessor (i.e. `foo?`) for
        # convenience.
        val = args.first

        # the second argument is only required when adding boolean accessors
        add_accessors([attr], attr => val)

        begin
          mth = method(name)
        rescue NameError
          raise NoMethodError, "Cannot set #{attr} on this object."
        end
        return mth.call(args[0])
      elsif @values.key?(name)
        return @values[name]
      end

      super
    end

    def respond_to_missing?(symbol, include_private = false)
      @values && @values.key?(symbol) || super
    end

    # Re-initializes the object based on a hash of values (usually one that's
    # come back from an API call). Adds or removes value accessors as necessary
    # and updates the state of internal data.
    #
    # Protected on purpose! Please do not expose.
    #
    # ==== Options
    #
    # * +:values:+ Hash used to update accessors and values.
    # * +:opts:+ Options for CapapiObject like an API key.
    # * +:partial:+ Indicates that the re-initialization should not attempt to
    #   remove accessors.
    def initialize_from(values, opts, partial = false)
      @opts = Util.normalize_opts(opts)

      removed = partial ? Set.new : Set.new(@values.keys - values.keys)
      added = Set.new(values.keys - @values.keys)

      # Wipe old state before setting new.
      remove_accessors(removed)
      add_accessors(added, values)

      removed.each do |k|
        @values.delete(k)
      end

      update_attributes(values, opts)

      self
    end

    private

    # Produces a deep copy of the given object including support for arrays,
    # hashes, and CapapiObjects.
    def self.deep_copy(obj)
      case obj
      when Array
        obj.map { |e| deep_copy(e) }
      when Hash
        obj.each_with_object({}) do |(k, v), copy|
          copy[k] = deep_copy(v)
          copy
        end
      when CapapiObject
        obj.class.construct_from(
          deep_copy(obj.instance_variable_get(:@values)),
          obj.instance_variable_get(:@opts).select do |k, _v|
            Util::OPTS_COPYABLE.include?(k)
          end
        )
      else
        obj
      end
    end
    private_class_method :deep_copy

  end
end
