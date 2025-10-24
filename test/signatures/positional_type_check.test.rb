# frozen_string_literal: true

test "basic function taking a string" do
	mod = Module.new do
		extend self

		fun example(foo = String) => String do
			foo
		end
	end

	assert_equal mod.example("Hello"), "Hello"
end

test "raises when given the wrong input" do
	mod = Module.new do
		extend self

		fun example(foo = String) => String do
			foo
		end
	end

	assert_raises Empirical::TypeError do
		mod.example(1)
	end
end

# TODO:
# Wrong structure
# With a local type
# With a constant type
# With a generic (method) type
# With a nilable type
# With a generic with a brace block
