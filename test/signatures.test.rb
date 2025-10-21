# frozen_string_literal: true

test "no return type, no args leaves as is" do
	processed = Empirical::Processor.call(<<~RUBY)
		def foo
			"a"
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo
			"a"
		end
	RUBY
end

test "no return type, required keyword arg leaves as is" do
	processed = Empirical::Processor.call(<<~RUBY)
		def foo(a:)
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a:)
			a
		end
	RUBY
end

test "no return type, optional keyword arg leaves as is" do
	processed = Empirical::Processor.call(<<~RUBY)
		def foo(a: nil)
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a: nil)
			a
		end
	RUBY
end

test "no return type, required positional arg leaves as is" do
	processed = Empirical::Processor.call(<<~RUBY)
		def foo(a)
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a)
			a
		end
	RUBY
end

test "no return type, optional positional arg leaves as is" do
	processed = Empirical::Processor.call(<<~RUBY)
		def foo(a = nil)
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a = nil)
			a
		end
	RUBY
end

test "no return type, mixed args leaves as is" do
	processed = Empirical::Processor.call(<<~RUBY)
		def foo(a, b = nil, c:, d: nil)
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a, b = nil, c:, d: nil)
			a
		end
	RUBY
end

test "return type, no args processes" do
	processed = Empirical::Processor.call(<<~RUBY)
		def say_hello = String do
			"Hello World!"
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def say_hello;__literally_returns__ = (;
			"Hello World!"
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "_Void return type, no args processes" do
	processed = Empirical::Processor.call(<<~RUBY)
		def return_nothing = _Void do
			background_work
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def return_nothing;__literally_returns__ = (;
			background_work
		;);binding.assert(__literally_returns__: _Void);__literally_returns__;end
	RUBY
end

test "_Any? return type, no args processes" do
	processed = Empirical::Processor.call(<<~RUBY)
		def foo = _Any? do
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo;__literally_returns__ = (;
			a
		;);binding.assert(__literally_returns__: _Any?);__literally_returns__;end
	RUBY
end

test "return type, positional arg processes" do
	processed = Empirical::Processor.call(<<~'RUBY')
		def say_hello(name = String) = String do
			"Hello #{name}!"
		end
	RUBY

	assert_equal_ruby(processed, <<~'RUBY')
		def say_hello(name = nil);binding.assert(name: String);__literally_returns__ = (;
			"Hello #{name}!"
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "return type, positional arg with default processes" do
	processed = Empirical::Processor.call(<<~'RUBY')
		def say_hello(name = String {"World"}) = String do
			"Hello #{name}!"
		end
	RUBY

	assert_equal_ruby(processed, <<~'RUBY')
		def say_hello(name = ("World"));binding.assert(name: String);__literally_returns__ = (;
			"Hello #{name}!"
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "return type, keyword arg processes" do
	processed = Empirical::Processor.call(<<~'RUBY')
		def say_hello(name: String) = String do
			"Hello #{name}!"
		end
	RUBY

	assert_equal_ruby(processed, <<~'RUBY')
		def say_hello(name: nil);binding.assert(name: String);__literally_returns__ = (;
			"Hello #{name}!"
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "positional and keyword" do
	processed = Empirical::Processor.call(<<~'RUBY')
		def say_hello(greeting = String, name: String) = String do
		  "#{greeting} #{name}!"
		end
	RUBY

	assert_equal_ruby(processed, <<~'RUBY')
		def say_hello(greeting = nil, name: nil);binding.assert(greeting: String, name: String);__literally_returns__ = (;
		  "#{greeting} #{name}!"
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	processed = Empirical::Processor.call(<<~'RUBY')
		def say_hello(name: String {"World"}) = String do
			"Hello #{name}!"
		end
	RUBY

	assert_equal_ruby(processed, <<~'RUBY')
		def say_hello(name: ("World"));binding.assert(name: String);__literally_returns__ = (;
			"Hello #{name}!"
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	assert_raises(Empirical::TypedSignatureError) do
		Empirical::Processor.call(<<~'RUBY')
   def say_hello(foo, name: String {"World"}) = String do
   	"Hello #{name}!"
   end
		RUBY
	end
end

test "basic" do
	processed = Empirical::Processor.call(<<~RUBY)
		def foo(a: Integer, b: String) = Numeric do
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a: nil, b: nil);binding.assert(a: Integer, b: String);__literally_returns__ = (;
			a
		;);binding.assert(__literally_returns__: Numeric);__literally_returns__;end
	RUBY
end

# test "no parens" do
# 	# this doesn't work, as Prism sees this as: `def foo(a: (Integer), b: (String = Numeric))`
# 	processed = Empirical::Processor.call(<<~'RUBY')
# 		def foo a: Integer, b: String = Numeric do
# 			a
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~'RUBY'
# 		def foo(a: nil, b: nil);binding.assert(a: Integer, b: String);__literally_returns__ = (;
# 			a
# 		;);binding.assert(__literally_returns__: Numeric);__literally_returns__;end
# 	RUBY
# end

test "with generic return type" do
	processed = Empirical::Processor.call(<<~RUBY)
		def foo(a: Integer, b: String) = _String(length: 10) do
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a: nil, b: nil);binding.assert(a: Integer, b: String);__literally_returns__ = (;
			a
		;);binding.assert(__literally_returns__: _String(length: 10));__literally_returns__;end
	RUBY
end

test "with generic input types" do
	processed = Empirical::Processor.call(<<~RUBY)
		def foo(a: _Integer(1..), b: String(length: 10)) = String do
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a: nil, b: nil);binding.assert(a: _Integer(1..), b: String(length: 10));__literally_returns__ = (;
			a
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "brace block" do
	processed = Empirical::Processor.call(<<~RUBY)
		def foo(a: Integer, b: String) = Numeric {
			a
		}
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a: nil, b: nil);binding.assert(a: Integer, b: String);__literally_returns__ = (;
			a
		;);binding.assert(__literally_returns__: Numeric);__literally_returns__;end
	RUBY
end

# test "_Void return type, no args processes" do
# 	processed = Empirical::Processor.call(<<~'RUBY')
# 		def return_nothing(foo: String, **bar) = Integer do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~'RUBY'

# 	RUBY
# end

test "return type, keyword arg with default processes" do
	processed = Empirical::Processor.call(<<~'RUBY')
		def say_hello(names = [String]) = String do
			"Hello #{names.join(", ")}!"
		end
	RUBY

	assert_equal_ruby(processed, <<~'RUBY')
		def say_hello(*names );binding.assert(names: ::Literal::_Array(String));__literally_returns__ = (;
			"Hello #{names.join(", ")}!"
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	processed = Empirical::Processor.call(<<~'RUBY')
		def say_hello(names = [_Deferred { foo }]) = String do
			"Hello #{names.join(", ")}!"
		end
	RUBY

	assert_equal_ruby(processed, <<~'RUBY')
		def say_hello(*names );binding.assert(names: ::Literal::_Array(_Deferred { foo }));__literally_returns__ = (;
			"Hello #{names.join(", ")}!"
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	processed = Empirical::Processor.call(<<~'RUBY')
		def say_hello(names = ([String])) = String do
			"Hello #{names.join(", ")}!"
		end
	RUBY

	assert_equal_ruby(processed, <<~'RUBY')
		def say_hello(names = nil);binding.assert(names: ([String]));__literally_returns__ = (;
			"Hello #{names.join(", ")}!"
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	processed = Empirical::Processor.call(<<~'RUBY')
		def say_hello(names: {_Deferred { foo } => String}) = String do
			"Hello #{names.join(", ")}!"
		end
	RUBY

	assert_equal_ruby(processed, <<~'RUBY')
		def say_hello(**names);binding.assert(names: ::Literal::_Hash(_Deferred { foo }, String));__literally_returns__ = (;
			"Hello #{names.join(", ")}!"
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	processed = Empirical::Processor.call(<<~'RUBY')
		def say_hello(names: ({_Deferred { foo } => String})) = String do
			"Hello #{names.join(", ")}!"
		end
	RUBY

	assert_equal_ruby(processed, <<~'RUBY')
		def say_hello(names: nil);binding.assert(names: ({_Deferred { foo } => String}));__literally_returns__ = (;
			"Hello #{names.join(", ")}!"
		;);binding.assert(__literally_returns__: String);__literally_returns__;end
	RUBY
end

test "arg splat with named type" do
	processed = Empirical::Processor.call(<<~RUBY)
		def move_to(position = [*Position]) = _Void do
			do_something
		end
	RUBY

	assert_equal processed, <<~RUBY
		def move_to(*position );binding.assert(position: Position);__literally_returns__ = (;
			do_something
		;);binding.assert(__literally_returns__: _Void);__literally_returns__;end
	RUBY
end

test "kwarg splat with named type" do
	processed = Empirical::Processor.call(<<~RUBY)
		def move_to(position: {**Position}) = _Void do
			do_something
		end
	RUBY

	assert_equal processed, <<~RUBY
		def move_to(**position);binding.assert(position: Position);__literally_returns__ = (;
			do_something
		;);binding.assert(__literally_returns__: _Void);__literally_returns__;end
	RUBY
end
