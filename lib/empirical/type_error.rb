# frozen_string_literal: true

class Empirical::TypeError < ::TypeError
	def self.argument_type_error(name:, value:, expected:, method_name:, context:)
		new(<<~MESSAGE)
			Method #{method_name} called with the wrong type for the argument #{name}.

			  #{describe(context, method_name)}
			    #{name}:
			      Expected: #{expected.inspect}
			      Actual (#{class_of(value)}): #{describe_value(value)}
		MESSAGE
	end

	def self.return_type_error(value:, expected:, method_name:, context:)
		new(<<~MESSAGE)
			Method #{method_name} returned the wrong type.

			  #{describe(context, method_name)}
			    Expected: #{expected.inspect}
			    Actual (#{class_of(value)}): #{describe_value(value)}
		MESSAGE
	end

	def self.ivar_type_error(name:, value:, expected:, context:)
		new(<<~MESSAGE)
			Instance variable #{name} assigned the wrong type.

			  #{class_of(context)}
			    #{name}:
			      Expected: #{expected.inspect}
			      Actual (#{class_of(value)}): #{describe_value(value)}
		MESSAGE
	end

	private_class_method def self.describe(context, method_name)
		owner = Empirical::METHOD_METHOD.bind_call(context, method_name).owner

		if owner.singleton_class?
			"#{describe_value(context)}.#{method_name}"
		else
			"#{owner.name || owner.inspect}##{method_name}"
		end
	rescue ::NameError
		method_name.to_s
	end

	private_class_method def self.class_of(value)
		Empirical::CLASS_METHOD.bind_call(value)
	end

	private_class_method def self.describe_value(value)
		value.inspect
	rescue ::NoMethodError
		"#<#{class_of(value)}>"
	end
end
