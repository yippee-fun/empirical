# frozen_string_literal: true

test "typed positional splat" do
	mod = Module.new do
		extend self

		fun example(numbers: [Integer]) => Integer do
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

test "typed positional splat with keywords" do
	mod = Module.new do
		extend self

		fun example(rest: [Integer], label: String, suffix?: String) => Array do
			[label, rest, suffix]
		end
	end

	assert_equal mod.method(:example).parameters, [[:rest, :rest], [:keyreq, :label], [:key, :suffix]]
	assert_equal mod.example(1, 2, label: "a"), ["a", [1, 2], nil]
	assert_equal mod.example(label: "a", suffix: "!"), ["a", [], "!"]

	assert_raises Empirical::TypeError do
		mod.example("1", label: "a")
	end

	assert_raises Empirical::TypeError do
		mod.example(1, label: :a)
	end
end

test "typed positional splat with a keyword splat" do
	mod = Module.new do
		extend self

		fun example(rest: [Integer], options: { Symbol => Integer }) => Array do
			[rest, options]
		end
	end

	assert_equal mod.example(1, a: 2), [[1], { a: 2 }]
end

test "array literals that aren’t splats can follow a keyword" do
	mod = Module.new do
		extend self

		fun example(name: String, flags: [], kinds: %i[on]) => Array do
			[name, flags, kinds]
		end
	end

	assert_equal mod.example(name: "a", flags: [], kinds: [:on]), ["a", [], [:on]]
end
