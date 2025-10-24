# frozen_string_literal: true

test "void return with natural return" do
	fun foo_1 => void do
		1
	end

	assert Empirical::VoidClass === foo_1
end

test "void return with early return" do
	assert_raises RuntimeError do
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

# test "basic empty function with never return where never is a local" do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
# 		never = 1
# 		fun foo => never do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~RUBY
# 		never = 1
# 		def foo;__literally_returns__ = (;
# 		;);raise(::Empirical::NeverError.new);end
# 	RUBY
# end

# test "basic empty function with constant return value" do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
# 		fun foo => String do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~RUBY
# 		def foo;__literally_returns__ = (;
# 		;);raise(::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: __method__, context: self)) unless String === __literally_returns__;__literally_returns__;end
# 	RUBY
# end

# test "basic empty function with generic return value" do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
# 		fun foo => _Integer(10..) do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~RUBY
# 		def foo;__literally_returns__ = (;
# 		;);raise(::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: _Integer(10..), method_name: __method__, context: self)) unless _Integer(10..) === __literally_returns__;__literally_returns__;end
# 	RUBY
# end

# test "function with keyword param" do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
# 		fun foo(bar: String) => void do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~RUBY
# 		def foo(bar: nil);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: String, method_name: __method__, context: self)) unless String === bar;__literally_returns__ = (;
# 		;);::Empirical::Void;end
# 	RUBY
# end

# test "function with positional param" do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
# 		fun foo(bar = String) => void do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~RUBY
# 		def foo(bar = nil);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: String, method_name: __method__, context: self)) unless String === bar;__literally_returns__ = (;
# 		;);::Empirical::Void;end
# 	RUBY
# end

# test "function with positional splat" do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
# 		fun foo(bar = [String]) => void do
# 		end
# 	RUBY

# 	assert_equal processed, <<~RUBY
# 		def foo(*bar);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: ::Literal::_Array(String), method_name: __method__, context: self)) unless ::Literal::_Array(String) === bar;__literally_returns__ = (;
# 		;);::Empirical::Void;end
# 	RUBY
# end

# test "function with keyword splat" do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
# 		fun foo(bar: { String => Integer }) => void do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~RUBY
# 		def foo(**bar);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: ::Literal::_Hash(String, Integer), method_name: __method__, context: self)) unless ::Literal::_Hash(String, Integer) === bar;__literally_returns__ = (;
# 		;);::Empirical::Void;end
# 	RUBY
# end

# test "function with default positional" do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
# 		fun foo(bar = Integer | 20) => void do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~RUBY
# 		def foo(bar = 20);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: Integer, method_name: __method__, context: self)) unless Integer === bar;__literally_returns__ = (;
# 		;);::Empirical::Void;end
# 	RUBY
# end

# test "function with default keyword" do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
# 		fun foo(bar: Integer | 20) => void do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~RUBY
# 		def foo(bar: 20);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: Integer, method_name: __method__, context: self)) unless Integer === bar;__literally_returns__ = (;
# 		;);::Empirical::Void;end
# 	RUBY
# end

# test "basic empty function with void return" do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
# 		fun self.foo => void do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~RUBY
# 		def self.foo;__literally_returns__ = (;
# 		;);::Empirical::Void;end
# 	RUBY
# end

# test "basic empty function with nilable type" do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
# 		fun foo(name?: String) => void do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~RUBY
# 		def foo(name: nil);raise(::Empirical::TypeError.argument_type_error(name: 'name', value: name, expected: ::Literal::_Nilable(String), method_name: __method__, context: self)) unless ::Literal::_Nilable(String) === name;__literally_returns__ = (;
# 		;);::Empirical::Void;end
# 	RUBY
# end
