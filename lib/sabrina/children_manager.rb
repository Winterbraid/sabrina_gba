module Sabrina
  # Implements +attr_children+, an +attr_accessor+-like macro that allows
  # passing down attribute write calls to an arbitrary array of objects.
  # Obviously, the child objects should support writing to the specified
  # attributes.
  #
  # Classes should override +#children+ to return a meaningful array of
  # child objects.
  module ChildrenManager
    # Adds a macro for attribute with children update.
    module AttrChildren
      private

      # Takes any number of symbols and creates writers that will also
      # pass the value down to each value in +children+.
      def attr_writer_children(*args)
        args.each do |x|
          x_var = "@#{x}".to_sym
          x_setter = "#{x}=".to_sym

          lamb = generate_writer_children(x_setter, x_var)

          define_method(x_setter, lamb) unless respond_to?(x_setter)
        end
      end

      # Takes any number of symbols and creates accessors that will also
      # pass the value down to each value in +children+.
      def attr_children(*args)
        attr_reader(*args)
        attr_writer_children(*args)
      end

      def generate_writer_children(name, variable)
        lambda do |value|
          children.each do |c|
            next c.method(name).call(value) if c.respond_to?(name)
            fail "Child #{c} has no method #{name}, yet attr_children called."
          end
          instance_variable_set(variable, value)
        end
      end
    end

    class << self
      # Magic for adding class methods when included.
      def included(mod)
        mod.extend(AttrChildren)
      end
    end

    # Classes should override this to provide a meaningful array
    # of children.
    #
    # @return [Array]
    def children
      instance_variable_defined?(:@children) ? @children : []
    end
  end
end
