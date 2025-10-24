# frozen_string_literal: true

test "basic function returning a string" do
	mod = Module.new do
		extend self

		fun example => String do
			"Hello"
		end
	end

	assert_equal mod.example, "Hello"
end

test "raises when returning the wrong type" do
	mod = Module.new do
		extend self

		fun example => String do
			1
		end
	end

	assert_raises(Empirical::TypeError) do
		mod.example
	end
end

test "raises when early returning the wrong type" do
	mod = Module.new do
		extend self

		fun example => String do
			return 1 if true
			"Hello"
		end
	end

	assert_raises(Empirical::TypeError) do
		mod.example
	end
end
