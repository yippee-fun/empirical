# frozen_string_literal: true

test "function with default keyword argument" do
	mod = Module.new do
		extend self

		fun example(name: String | "World") => String do
			"Hello #{name}"
		end
	end

	assert_equal mod.example, "Hello World"
	assert_equal mod.example(name: "Joel"), "Hello Joel"
end
