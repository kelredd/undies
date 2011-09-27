require 'undies/source'
require 'undies/node'
require 'undies/element'

module Undies
  class Template

    # prefixing with a triple underscore to not pollut metaclass locals scope

    attr_accessor :___nodes

    def initialize(*args, &block)
      self.___nodes = NodeList.new
      targs = self.___template_args(args.compact, block)
      self.___locals, self.___io, self.___layout, self.___markup = targs
      self.___stack = ElementStack.new(self, self.___io)
      self.___compile { self.___render(self.___markup) if self.___layout }
    end

    def to_s(pp_indent=nil)
      self.___nodes.to_s(0, pp_indent)
    end

    # Add a text node (data escaped) to the nodes of the current node
    def _(data="")
      self.__ self.escape_html(data.to_s)
    end

    # Add a text node with the data un-escaped
    def __(data="")
      node = Node.new(data.to_s)
      self.___io << node.to_s if self.___io
      self.___add(node)
    end

    # Add an element to the nodes of the current node
    def element(name, attrs={}, &block)
      self.___add(Element.new(self.___stack, name, attrs, &block))
    end
    alias_method :tag, :element

    # Element proxy methods ('_<element>'') ========================
    ELEM_METH_REGEX = /^_(.+)$/

    def method_missing(meth, *args, &block)
      if meth.to_s =~ ELEM_METH_REGEX
        element($1, *args, &block)
      else
        super
      end
    end

    def respond_to?(*args)
      if args.first.to_s =~ ELEM_METH_REGEX
        true
      else
        super
      end
    end
    # ==============================================================

    # Ripped from Rack v1.3.0 ======================================
    # => ripped b/c I don't want a dependency on Rack for just this
    ESCAPE_HTML = {
      "&" => "&amp;",
      "<" => "&lt;",
      ">" => "&gt;",
      "'" => "&#x27;",
      '"' => "&quot;",
      "/" => "&#x2F;"
    }
    ESCAPE_HTML_PATTERN = Regexp.union(*ESCAPE_HTML.keys)

    # Escape ampersands, brackets and quotes to their HTML/XML entities.
    def escape_html(string)
      string.to_s.gsub(ESCAPE_HTML_PATTERN){|c| ESCAPE_HTML[c] }
    end
    # end Rip from Rack v1.3.0 =====================================

    protected

    # prefixing non-public methods with a triple underscore to not pollute
    # metaclass locals scope

    def ___compile
      self.___render(self.___layout || self.___markup)
    end

    def ___render(source)
      if source.file?
        instance_eval(source.data, source.source, 1)
      else
        instance_eval(&source.data)
      end
    end

    def ___locals=(data)
      if !data.kind_of?(::Hash)
        raise ArgumentError
      end
      if invalid_locals?(data.keys)
        raise ArgumentError, "locals conflict with template's public methods."
      end
      data.each do |key, value|
        self.___metaclass do
          define_method(key) { value }
        end
      end
    end

    def ___add(node)
      self.___stack.last.___nodes.append(node)
    end

    def ___stack
      @stack
    end

    def ___stack=(value)
      raise ArgumentError if !value.respond_to?(:push) || !value.respond_to?(:pop)
      @stack = value
    end

    def ___io
      @io
    end

    def ___io=(value)
      raise ArgumentError if value && !self.___is_a_stream?(value)
      @io = value
    end

    def ___layout
      @layout
    end

    def ___layout=(value)
      if value && !(value.kind_of?(Source) && value.file?)
        raise ArgumentError, "layout must be a file source"
      end
      @layout = value
    end

    def ___markup
      @markup
    end

    def ___markup=(value)
      raise ArgumentError if value && !value.kind_of?(Source)
      @markup = value
    end

    def ___template_args(args, block)
      [ args.last.kind_of?(::Hash) ? args.pop : {},
        self.___is_a_stream?(args.last) ? args.pop : nil,
        self.___layout_arg?(args, block) ? Source.new(args.pop) : nil,
        Source.new(args.first || block)
      ]
    end

    def ___metaclass(&block)
      metaclass = class << self; self; end
      metaclass.class_eval(&block)
    end

    def ___is_a_stream?(thing)
      !thing.kind_of?(::String) && thing.respond_to?(:<<)
    end

    def ___layout_arg?(args, block)
      if args.size >= 2
        true
      elsif args.size <= 0
        false
      else # args.size == 1
        !block.nil?
      end
    end

    private

    # you can't define locals that conflict with the template's public methods
    def invalid_locals?(keys)
      (keys.collect(&:to_s) & self.public_methods.collect(&:to_s)).size > 0
    end

  end
end
