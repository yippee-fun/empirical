# frozen_string_literal: true

test "untyped splats and block pass straight through" do
	mod = Module.new do
		extend self

		fun example(*args, **kwargs, &block) => Array do
			[args, kwargs, block.call]
		end
	end

	assert_equal mod.method(:example).parameters, [[:rest, :args], [:keyrest, :kwargs], [:block, :block]]
	assert_equal mod.example(1, a: 2) { 3 }, [[1], { a: 2 }, 3]
end

test "block parameter after typed parameters" do
	mod = Module.new do
		extend self

		fun example(name: String, greeting: String, &block) => String do
			block.call("#{greeting} #{name}")
		end
	end

	assert_equal mod.example(name: "Joel", greeting: "Hello", &:upcase), "HELLO JOEL"

	assert_raises Empirical::TypeError do
		mod.example(name: 1, greeting: "Hello", &:upcase)
	end
end

test "typed keyword with an untyped keyword splat" do
	mod = Module.new do
		extend self

		fun example(name: String, **rest) => Array do
			[name, rest]
		end
	end

	assert_equal mod.example(name: "Joel", a: 1), ["Joel", { a: 1 }]
end
