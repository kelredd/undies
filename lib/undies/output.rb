require 'undies/node'
require 'undies/element'
require 'undies/node_buffer'

module Undies
  class Output

    attr_reader :io, :options, :pp, :node_buffer

    # the output class wraps an IO stream, gathers pretty printing options,
    # and handles buffering nodes and pretty printing to the stream

    def initialize(io, opts={})
      @io = io
      self.options = opts
      @node_buffer = NodeBuffer.new
    end

    def options=(opts)
      if !opts.kind_of?(::Hash)
        raise ArgumentError, "please provide a hash to set options with"
      end

      # setup any pretty printing
      @pp = opts[:pp]
      self.pp_level = opts[:pp_level] || 0
      self.pp_use_indent = true

      @options = opts
    end

    def pp_level
      @pp_level
    end

    def pp_level=(value)
      @pp_indent = @pp ? "\n#{' '*value*@pp}" : ""
      @pp_level  = value
    end

    def pp_use_indent=(value)
      @pp_use_indent = value
    end

    def <<(data)
      @io << (@pp_use_indent ? "#{@pp_indent}#{data}" : data.to_s)
    end

    def node(data="")
      self.node_buffer.pull(self)
      self.node_buffer.push(Node.new(data))
    end

    def element(name, attrs={}, &block)
      self.node_buffer.pull(self)
      self.node_buffer.push(Element.new(name, attrs, &block))
    end

    def flush
      self.node_buffer.flush(self)
    end

  end
end
