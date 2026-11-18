# frozen_string_literal: true

test "void return with natural return" do
	fun foo_1 => void do
		1
	end

	assert Empirical::VoidClass === foo_1
end

test "void return with early return" do
	assert_raises Empirical::TypedSignatureError do
		eval <<~RUBY
			fun foo_2 => void do
				return 1
			end
		RUBY
	end
end

test "basic empty function where the function name is a local" do
	foo_3 = 1

	fun foo_3 => Integer do
		1
	end

	assert_equal self.foo_3, 1
end

test "basic empty function with void return where the function name is a constant" do
	fun Foo_4 => Integer do
		1
	end

	assert_equal Foo_4(), 1
end

test "basic empty function with void return where void is a local" do
	void = 1

	fun foo_5 => void do
		2
	end

	assert Empirical::VoidClass === foo_5
end

test "basic empty function with never return" do
	fun foo_6 => never do
		1
	end

	assert_raises Empirical::NeverError do
		foo_6
	end
end
