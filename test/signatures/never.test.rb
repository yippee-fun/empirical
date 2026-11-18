# frozen_string_literal: true

test "never raises when the method returns naturally" do
	mod = Module.new do
		extend self

		fun example => never do
			1
		end
	end

	assert_raises Empirical::NeverError do
		mod.example
	end
end

test "never raises on an early return" do
	mod = Module.new do
		extend self

		fun example => never do
			return if true
			raise "unreachable"
		end
	end

	assert_raises Empirical::NeverError do
		mod.example
	end
end

test "never raises on an early return with a value" do
	mod = Module.new do
		extend self

		fun example => never do
			return 1 if true
			raise "unreachable"
		end
	end

	assert_raises Empirical::NeverError do
		mod.example
	end
end

test "never lets the method’s own exception through" do
	mod = Module.new do
		extend self

		fun example => never do
			raise ArgumentError
		end
	end

	assert_raises ArgumentError do
		mod.example
	end
end
