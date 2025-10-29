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

test "method overloaded with positional arguments with explicit receiver" do
	mod = Module.new do
		overload fun self.example(input = String) => String do
			"Called with a string"
		end

		overload fun self.example(input = Integer) => String do
			"Called with an integer"
		end
	end

	overload fun mod.example(input = Float) => String do
		"Called with a float"
	end

	assert_equal mod.example("Hi"), "Called with a string"
	assert_equal mod.example(42), "Called with an integer"
	assert_equal mod.example(3.14), "Called with a float"

	assert_raises NoMatchingPatternError do
		mod.example(true)
	end
end
