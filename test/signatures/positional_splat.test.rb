# frozen_string_literal: true

test "typed positional splat" do
	mod = Module.new do
		extend self

		fun example(numbers = [Integer]) => Integer do
			numbers.sum
		end
	end

	assert_equal mod.method(:example).parameters, [[:rest, :numbers]]
	assert_equal mod.example(1, 2, 3), 6
	assert_equal mod.example, 0

	assert_raises Empirical::TypeError do
		mod.example(1, "2")
	end
end

test "typed positional splat after a positional" do
	mod = Module.new do
		extend self

		fun example(first = String, rest = [Integer]) => Array do
			[first, rest]
		end
	end

	assert_equal mod.example("a", 1, 2), ["a", [1, 2]]
end
