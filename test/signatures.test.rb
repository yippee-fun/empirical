# frozen_string_literal: true

test "no return type, no args leaves as is" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
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
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
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
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
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
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
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
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
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
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
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
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		def say_hello = String do
			"Hello World!"
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def say_hello;__literally_returns__ = (;
			"Hello World!"
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'say_hello', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "_Void return type, no args processes" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		def return_nothing = _Void do
			background_work
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def return_nothing;__literally_returns__ = (;
			background_work
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: _Void, method_name: 'return_nothing', context: self) unless _Void === __literally_returns__);__literally_returns__;end
	RUBY
end

test "_Any? return type, no args processes" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		def foo = _Any? do
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo;__literally_returns__ = (;
			a
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: _Any?, method_name: 'foo', context: self) unless _Any? === __literally_returns__);__literally_returns__;end
	RUBY
end

test "return type, positional arg processes" do
	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
		def say_hello(name = String) = String do
			"Hello #{name}!"
		end
	RUBY

	assert_equal(processed, <<~'RUBY')
		def say_hello(name = nil);(raise ::Empirical::TypeError.argument_type_error(name: 'name', value: name, expected: String, method_name: 'say_hello', context: self) unless String === name);__literally_returns__ = (;
			"Hello #{name}!"
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'say_hello', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "return type, positional arg with default processes" do
	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
		def say_hello(name = String {"World"}) = String do
			"Hello #{name}!"
		end
	RUBY

	assert_equal(processed, <<~'RUBY')
		def say_hello(name = ("World"));(raise ::Empirical::TypeError.argument_type_error(name: 'name', value: name, expected: String, method_name: 'say_hello', context: self) unless String === name);__literally_returns__ = (;
			"Hello #{name}!"
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'say_hello', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "return type, keyword arg processes" do
	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
		def say_hello(name: String) = String do
			"Hello #{name}!"
		end
	RUBY

	assert_equal(processed, <<~'RUBY')
		def say_hello(name: nil);(raise ::Empirical::TypeError.argument_type_error(name: 'name', value: name, expected: String, method_name: 'say_hello', context: self) unless String === name);__literally_returns__ = (;
			"Hello #{name}!"
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'say_hello', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "positional and keyword" do
	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
		def say_hello(greeting = String, name: String) = String do
		  "#{greeting} #{name}!"
		end
	RUBY

	assert_equal(processed, <<~'RUBY')
		def say_hello(greeting = nil, name: nil);(raise ::Empirical::TypeError.argument_type_error(name: 'greeting', value: greeting, expected: String, method_name: 'say_hello', context: self) unless String === greeting);(raise ::Empirical::TypeError.argument_type_error(name: 'name', value: name, expected: String, method_name: 'say_hello', context: self) unless String === name);__literally_returns__ = (;
		  "#{greeting} #{name}!"
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'say_hello', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
		def say_hello(name: String {"World"}) = String do
			"Hello #{name}!"
		end
	RUBY

	assert_equal(processed, <<~'RUBY')
		def say_hello(name: ("World"));(raise ::Empirical::TypeError.argument_type_error(name: 'name', value: name, expected: String, method_name: 'say_hello', context: self) unless String === name);__literally_returns__ = (;
			"Hello #{name}!"
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'say_hello', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	assert_raises(Empirical::TypedSignatureError) do
		Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
   def say_hello(foo, name: String {"World"}) = String do
   	"Hello #{name}!"
   end
		RUBY
	end
end

test "basic" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		def foo(a: Integer, b: String) = Numeric do
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a: nil, b: nil);(raise ::Empirical::TypeError.argument_type_error(name: 'a', value: a, expected: Integer, method_name: 'foo', context: self) unless Integer === a);(raise ::Empirical::TypeError.argument_type_error(name: 'b', value: b, expected: String, method_name: 'foo', context: self) unless String === b);__literally_returns__ = (;
			a
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: Numeric, method_name: 'foo', context: self) unless Numeric === __literally_returns__);__literally_returns__;end
	RUBY
end

# test "no parens" do
# 	# this doesn't work, as Prism sees this as: `def foo(a: (Integer), b: (String = Numeric))`
# 	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
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
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		def foo(a: Integer, b: String) = _String(length: 10) do
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a: nil, b: nil);(raise ::Empirical::TypeError.argument_type_error(name: 'a', value: a, expected: Integer, method_name: 'foo', context: self) unless Integer === a);(raise ::Empirical::TypeError.argument_type_error(name: 'b', value: b, expected: String, method_name: 'foo', context: self) unless String === b);__literally_returns__ = (;
			a
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: _String(length: 10), method_name: 'foo', context: self) unless _String(length: 10) === __literally_returns__);__literally_returns__;end
	RUBY
end

test "with generic input types" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		def foo(a: _Integer(1..), b: String(length: 10)) = String do
			a
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a: nil, b: nil);(raise ::Empirical::TypeError.argument_type_error(name: 'a', value: a, expected: _Integer(1..), method_name: 'foo', context: self) unless _Integer(1..) === a);(raise ::Empirical::TypeError.argument_type_error(name: 'b', value: b, expected: String(length: 10), method_name: 'foo', context: self) unless String(length: 10) === b);__literally_returns__ = (;
			a
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'foo', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "brace block" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		def foo(a: Integer, b: String) = Numeric {
			a
		}
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo(a: nil, b: nil);(raise ::Empirical::TypeError.argument_type_error(name: 'a', value: a, expected: Integer, method_name: 'foo', context: self) unless Integer === a);(raise ::Empirical::TypeError.argument_type_error(name: 'b', value: b, expected: String, method_name: 'foo', context: self) unless String === b);__literally_returns__ = (;
			a
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: Numeric, method_name: 'foo', context: self) unless Numeric === __literally_returns__);__literally_returns__;end
	RUBY
end

# test "_Void return type, no args processes" do
# 	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
# 		def return_nothing(foo: String, **bar) = Integer do
# 		end
# 	RUBY

# 	assert_equal_ruby processed, <<~'RUBY'

# 	RUBY
# end

test "return type, keyword arg with default processes" do
	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
		def say_hello(names = [String]) = String do
			"Hello #{names.join(", ")}!"
		end
	RUBY

	assert_equal(processed, <<~'RUBY')
		def say_hello(*names);(raise ::Empirical::TypeError.argument_type_error(name: 'names', value: names, expected: ::Literal::_Array(String), method_name: 'say_hello', context: self) unless ::Literal::_Array(String) === names);__literally_returns__ = (;
			"Hello #{names.join(", ")}!"
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'say_hello', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
		def say_hello(names = [_Deferred { foo }]) = String do
			"Hello #{names.join(", ")}!"
		end
	RUBY

	assert_equal(processed, <<~'RUBY')
		def say_hello(*names);(raise ::Empirical::TypeError.argument_type_error(name: 'names', value: names, expected: ::Literal::_Array(_Deferred { foo }), method_name: 'say_hello', context: self) unless ::Literal::_Array(_Deferred { foo }) === names);__literally_returns__ = (;
			"Hello #{names.join(", ")}!"
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'say_hello', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
		def say_hello(names = ([String])) = String do
			"Hello #{names.join(", ")}!"
		end
	RUBY

	assert_equal(processed, <<~'RUBY')
		def say_hello(names = nil);(raise ::Empirical::TypeError.argument_type_error(name: 'names', value: names, expected: ([String]), method_name: 'say_hello', context: self) unless ([String]) === names);__literally_returns__ = (;
			"Hello #{names.join(", ")}!"
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'say_hello', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
		def say_hello(names: {_Deferred { foo } => String}) = String do
			"Hello #{names.join(", ")}!"
		end
	RUBY

	assert_equal(processed, <<~'RUBY')
		def say_hello(**names);;__literally_returns__ = (;
			"Hello #{names.join(", ")}!"
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'say_hello', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "return type, keyword arg with default processes" do
	processed = Empirical.process(<<~'RUBY', with: Empirical::SignatureProcessor)
		def say_hello(names: ({_Deferred { foo } => String})) = String do
			"Hello #{names.join(", ")}!"
		end
	RUBY

	assert_equal(processed, <<~'RUBY')
		def say_hello(names: nil);(raise ::Empirical::TypeError.argument_type_error(name: 'names', value: names, expected: ({_Deferred { foo } => String}), method_name: 'say_hello', context: self) unless ({_Deferred { foo } => String}) === names);__literally_returns__ = (;
			"Hello #{names.join(", ")}!"
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: String, method_name: 'say_hello', context: self) unless String === __literally_returns__);__literally_returns__;end
	RUBY
end

test "arg splat with named type" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		def move_to(position = [*Position]) = _Void do
			do_something
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def move_to(*position);(raise ::Empirical::TypeError.argument_type_error(name: 'position', value: position, expected: Position, method_name: 'move_to', context: self) unless Position === position);__literally_returns__ = (;
			do_something
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: _Void, method_name: 'move_to', context: self) unless _Void === __literally_returns__);__literally_returns__;end
	RUBY
end

test "kwarg splat with named type" do
	processed = Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
		def move_to(position: {**Position}) = _Void do
			do_something
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def move_to(**position);(raise ::Empirical::TypeError.argument_type_error(name: 'position', value: position, expected: Position, method_name: 'move_to', context: self) unless Position === position);__literally_returns__ = (;
			do_something
		;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: _Void, method_name: 'move_to', context: self) unless _Void === __literally_returns__);__literally_returns__;end
	RUBY
end
