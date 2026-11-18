# frozen_string_literal: true

test "typed keyword splat" do
	mod = Module.new do
		extend self

		fun example(options: { Symbol => Integer }) => Integer do
			options.values.sum
		end
	end

	assert_equal mod.method(:example).parameters, [[:keyrest, :options]]
	assert_equal mod.example(a: 1, b: 2), 3
	assert_equal mod.example, 0

	assert_raises Empirical::TypeError do
		mod.example(a: "1")
	end
end

test "typed keyword splat after a keyword" do
	mod = Module.new do
		extend self

		fun example(name: String, options: { Symbol => Integer }) => Array do
			[name, options]
		end
	end

	assert_equal mod.example(a: 1, name: "Joel"), ["Joel", { a: 1 }]
end
