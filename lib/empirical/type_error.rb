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
end