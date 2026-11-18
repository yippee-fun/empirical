# frozen_string_literal: true

# rubocop:disable Style/MultilineIfModifier

test "postfix if and unless" do
	klass = Class.new do
		fun void_example => void do
			nil
		end if true

		fun never_example => never do
			raise "Failed"
		end unless false

		fun typed_example => String do
			"typed"
		end if true

		fun skipped => String do
			"skipped"
		end if false
	end

	assert_equal klass.new.typed_example, "typed"
	assert_equal klass.instance_method(:void_example).return_type, _Void
	assert_equal klass.instance_method(:never_example).return_type, _Never
	assert_equal klass.method_defined?(:skipped), false
end

test "evaluates to the method name" do
	name = nil

	Class.new do
		name = fun example(value = Integer) => Integer do
			value
		end
	end

	assert_equal name, :example
end

test "visibility modifiers with postfix if" do
	klass = Class.new do
		private fun example => String do
			"example"
		end if true
	end

	assert_equal klass.private_method_defined?(:example), true
end

# rubocop:enable Style/MultilineIfModifier
