# frozen_string_literal: true

test "basic empty function with void return" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun foo => void do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end

test "basic empty function with void return where the function name is a local" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		foo = 1
		fun foo => void do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		foo = 1
		def foo;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end

test "basic empty function with void return where the function name is a constant" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun Foo => void do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def Foo;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end

test "basic empty function with void return where void is a local" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		void = 1
		fun foo => void do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		void = 1
		def foo;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end

test "basic empty function with never return" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun foo => never do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo;__literally_returns__ = (;
		;);raise(::Empirical::NeverError.new);end
	RUBY
end

test "basic empty function with never return where never is a local" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		never = 1
		fun foo => never do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		never = 1
		def foo;__literally_returns__ = (;
		;);raise(::Empirical::NeverError.new);end
	RUBY
end

test "basic empty function with constant return value" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun foo => String do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo;__literally_returns__ = (;
		;);raise(::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: __method__, context: self)) unless String === __literally_returns__;__literally_returns__;end
	RUBY
end

test "basic empty function with generic return value" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun foo => _Integer(10..) do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo;__literally_returns__ = (;
		;);raise(::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: _Integer(10..), method_name: __method__, context: self)) unless _Integer(10..) === __literally_returns__;__literally_returns__;end
	RUBY
end

test "function with keyword param" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun foo(bar: String) => void do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(bar: nil);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: String, method_name: __method__, context: self)) unless String === bar;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end

test "function with positional param" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun foo(bar = String) => void do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(bar = nil);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: String, method_name: __method__, context: self)) unless String === bar;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end

test "function with positional splat" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun foo(bar = [String]) => void do
		end
	RUBY

	assert_equal processed, <<~RUBY
		def foo(*bar);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: ::Literal::_Array(String), method_name: __method__, context: self)) unless ::Literal::_Array(String) === bar;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end

test "function with keyword splat" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun foo(bar: { String => Integer }) => void do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(**bar);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: ::Literal::_Hash(String, Integer), method_name: __method__, context: self)) unless ::Literal::_Hash(String, Integer) === bar;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end

test "function with default positional" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun foo(bar = Integer | 20) => void do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(bar = 20);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: Integer, method_name: __method__, context: self)) unless Integer === bar;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end

test "function with default keyword" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun foo(bar: Integer | 20) => void do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(bar: 20);raise(::Empirical::TypeError.argument_type_error(name: 'bar', value: bar, expected: Integer, method_name: __method__, context: self)) unless Integer === bar;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end

test "basic empty function with void return" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun self.foo => void do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def self.foo;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end

test "basic empty function with nilable type" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		fun foo(name?: String) => void do
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(name: nil);raise(::Empirical::TypeError.argument_type_error(name: 'name', value: name, expected: ::Literal::_Nilable(String), method_name: __method__, context: self)) unless ::Literal::_Nilable(String) === name;__literally_returns__ = (;
		;);::Empirical::Void;end
	RUBY
end
