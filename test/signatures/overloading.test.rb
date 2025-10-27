# frozen_string_literal: true

test "method overloaded with positional arguments" do
	mod = Module.new do
		extend self

		overload fun example(input = String) => String do
			"Called with a string"
		end

		overload fun example(input = Integer) => String do
			"Called with an integer"
		end
	end

	assert_equal mod.example("Hi"), "Called with a string"
	assert_equal mod.example(42), "Called with an integer"

	assert_raises NoMatchingPatternError do
		mod.example(true)
	end
end
