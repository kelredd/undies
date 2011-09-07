require 'undies/node'
require 'undies/node_list'
require 'undies/element_stack'

module Undies
  class Element < Node

    attr_reader :name, :attrs
    attr_accessor :nodes

    def initialize(stack, name, attrs={}, &block)
      if !stack.kind_of?(ElementStack)
        raise ArgumentError, "stack must be an Undies::ElementStack"
      end
      super(@nodes = NodeList.new)
      @stack = stack
      @name = name.to_s
      @attrs = attrs
      @content_writes = 0
      self.content = block
    end

    def start_tag
      "<#{@name}#{html_attrs(@attrs)}" + (@content_writes > 0 ? ">" : " />")
    end

    def end_tag
      @content_writes > 0 ? "</#{@name}>" : nil
    end

    # CSS proxy methods ============================================
    ID_METH_REGEX = /^([^_].+)!$/
    CLASS_METH_REGEX = /^([^_].+)$/

    def method_missing(meth, *args, &block)
      if meth.to_s =~ ID_METH_REGEX
        proxy_id_attr($1, *args, &block)
      elsif meth.to_s =~ CLASS_METH_REGEX
        proxy_class_attr($1, *args, &block)
      else
        super
      end
    end

    def respond_to?(*args)
      if args.first.to_s =~ ID_METH_REGEX || args.first.to_s =~ CLASS_METH_REGEX
        true
      else
        super
      end
    end
    # ==============================================================

    def ==(other)
      other.name == self.name &&
      other.attrs == self.attrs &&
      other.nodes == self.nodes
    end

    def to_str(*args)
      "Undies::Element:#{self.object_id} " +
      "@name=#{@name.inspect}, @attrs=#{@attrs.inspect}, @nodes=#{@nodes.inspect}"
    end
    alias_method :inspect, :to_str

    def to_ary(*args)
      @nodes
    end

    protected

    def html_attrs(attrs={})
      raise ArgumentError unless attrs.kind_of? ::Hash
      if attrs.empty?
        ''
      else
        ' '+attrs.
        sort {|a,b|  a[0].to_s <=> b[0].to_s}.
        collect {|k_v| "#{k_v[0]}=\"#{k_v[1]}\""}.
        join(' ').
        strip
      end
    end

    private

    def proxy_id_attr(value, attrs={}, &block)
      @attrs.merge!(:id => value)
      @attrs.merge!(attrs)
      self.content = block
      self
    end

    def proxy_class_attr(value, attrs={}, &block)
      @attrs[:class] = [@attrs[:class], value].compact.join(' ')
      @attrs.merge!(attrs)
      self.content = block
      self
    end

    def content=(block)
      if block
        @content_writes += 1
        @stack.push(self)
        block.call
        @stack.pop
      end
    end

  end
end
