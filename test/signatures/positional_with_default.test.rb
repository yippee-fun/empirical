# frozen_string_literal: true

test "positional default is used and type checked" do
	mod = Module.new do
		extend self

		fun example(count = Integer) => Integer do |count: 1|
			count
		end
	end

	assert_equal mod.method(:example).parameters, [[:opt, :count]]
	assert_equal mod.example, 1
	assert_equal mod.example(2), 2

	assert_raises Empirical::TypeError do
		mod.example("2")
	end
end

test "a default of the wrong type raises when it is used" do
	mod = Module.new do
		extend self

		fun example(count = Integer) => Integer do |count: "one"|
			count
		end
	end

	assert_raises Empirical::TypeError do
		mod.example
	end
end

test "a default can refer to an earlier parameter" do
	mod = Module.new do
		extend self

		fun example(first = Integer, second = Integer) => Integer do |second: (first * 2)|
			second
		end
	end

	assert_equal mod.example(2), 4
end

test "nilable positional with a nil default" do
	mod = Module.new do
		extend self

		fun example(name = _Nilable(String)) => String do |name: nil|
			name || "nobody"
		end
	end

	assert_equal mod.example, "nobody"
	assert_equal mod.example("Joel"), "Joel"
end
