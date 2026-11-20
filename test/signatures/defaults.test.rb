# frozen_string_literal: true

test "optional keyword argument" do
	mod = Module.new do
		extend self

		fun example(name: String) => String do |name: "World"|
			"Hello #{name}!"
		end
	end

	assert_equal "Hello World!", mod.example
	assert_equal "Hello Alice!", mod.example(name: "Alice")
end

test "a default is type checked" do
	mod = Module.new do
		extend self

		fun example(count: Integer) => Integer do |count: 1|
			count
		end
	end

	assert_equal mod.method(:example).parameters, [[:key, :count]]
	assert_equal mod.example, 1
	assert_equal mod.example(count: 2), 2

	assert_raises Empirical::TypeError do
		mod.example(count: "2")
	end
end

test "a default of the wrong type raises when it is used" do
	mod = Module.new do
		extend self

		fun example(count: Integer) => Integer do |count: "one".itself|
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

		fun example(first: Integer, second: Integer) => Integer do |second: (first * 2)|
			second
		end
	end

	assert_equal mod.example(first: 2), 4
end

test "nilable keyword with a nil default" do
	mod = Module.new do
		extend self

		fun example(name: _Nilable(String)) => String do |name: nil|
			name || "nobody"
		end
	end

	assert_equal mod.example, "nobody"
	assert_equal mod.example(name: "Joel"), "Joel"
end
