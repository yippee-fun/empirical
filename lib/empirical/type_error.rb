# frozen_string_literal: true

class Empirical::TypeError < ::TypeError
	def self.argument_type_error(name:, value:, expected:, method_name:, context:)
		owner = context.method(method_name).owner
		sign = owner.singleton_class? ? "." : "#"

		new(<<~MESSAGE)
			Method #{method_name} called with the wrong type for the argument #{name}.

			  #{owner.name}#{sign}#{method_name}
			    #{name}:
			      Expected: #{expected.inspect}
			      Actual (#{value.class}): #{value.inspect}
		MESSAGE
	end

	def self.return_type_error(value:, expected:, method_name:, context:)
		owner = context.method(method_name).owner
		sign = owner.singleton_class? ? "." : "#"

		new(<<~MESSAGE)
			Method #{method_name} returned the wrong type.

			  #{owner.name}#{sign}#{method_name}
			    Expected: #{expected.inspect}
			    Actual (#{value.class}): #{value.inspect}
		MESSAGE
	end

  def self.attr_type_error(name:, value:, expected:, attr_type:, context:)
		context_class = context.class
		sign = context_class.singleton_class? ? "." : "#"

		operation = (attr_type == "reader") ? "read from" : "written to"
		method_name = "#{name}#{(attr_type == 'writer') ? '=' : ''}"

		new(<<~MESSAGE)
			Attribute #{name} #{operation} with the wrong type.

			  #{context_class.name}#{sign}#{method_name}
			    Expected: #{expected.inspect}
			    Actual (#{value.class}): #{value.inspect}
		MESSAGE
	end
end
