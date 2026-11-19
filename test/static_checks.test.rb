# frozen_string_literal: true

def static_error(source)
	Module.new.module_eval(source, File.join(Dir.pwd, "test/example.rb"), 1)
	nil
rescue Empirical::StaticTypeError => error
	error.message.delete_prefix("#{Dir.pwd}/test/")
end

test "a literal return of the wrong type is reported when the method is defined" do
	message = static_error(<<~RUBY)
		fun answer => String do
			1
		end
	RUBY

	assert_equal message, "example.rb:2: `answer` returns 1, which doesn’t match String."
end

test "a literal return of the right type is fine" do
	assert_equal static_error(<<~RUBY), nil
		fun answer => _Nilable(String) do
			return nil if rand > 2
			"yes"
		end
	RUBY
end

test "an empty body returns nil" do
	message = static_error(<<~RUBY)
		fun answer => String do
		end
	RUBY

	assert_equal message, "example.rb:1: `answer` returns nil, which doesn’t match String."
end

test "early returns" do
	assert static_error("fun answer => String do\n\treturn 1 if rand > 2\n\t'a'\nend").include?("example.rb:2: `answer` returns 1")
	assert static_error("fun answer => String do\n\treturn if rand > 2\n\t'a'\nend").include?("example.rb:2: `answer` returns nil")
end

test "both branches of a conditional" do
	message = static_error(<<~RUBY)
		fun answer(flag = _Boolean) => String do
			if flag
				"yes"
			else
				:no
			end
		end
	RUBY

	assert_equal message, "example.rb:5: `answer` returns :no, which doesn’t match String."
end

test "an if with no else doesn’t count the missing branch" do
	assert_equal static_error(<<~RUBY), nil
		fun answer(flag = _Boolean) => String do
			raise "no" unless flag
			"yes" if flag
		end
	RUBY
end

test "the value of a rescue clause" do
	message = static_error(<<~RUBY)
		fun answer => String do
			"yes"
		rescue
			0
		end
	RUBY

	assert_equal message, "example.rb:4: `answer` returns 0, which doesn’t match String."
end

test "literals are checked with the real type" do
	assert_equal static_error("fun answer => _Integer(1..) do\n\t5\nend"), nil
	assert static_error("fun answer => _Integer(1..) do\n\t0\nend").include?("`answer` returns 0, which doesn’t match")
	assert static_error("fun answer => _Array(Integer) do\n\t[1, :two]\nend").include?("`answer` returns [1, :two]")
	assert_equal static_error("String = Integer\nfun answer => String do\n\t1\nend"), nil
end

test "a return in a lambda isn’t the method’s return" do
	assert_equal static_error(<<~RUBY), nil
		fun answer => String do
			-> { return 1 }.call.to_s
		end
	RUBY
end

test "a return in an ensure replaces the body’s value" do
	assert_equal static_error(<<~RUBY), nil
		fun answer => String do
			1
		ensure
			return "ok" if true
		end
	RUBY
end

test "a nested fun’s returns belong to it" do
	assert_equal static_error(<<~RUBY), nil
		fun outer => String do
			fun inner => Integer do
				return 1 if true
				2
			end

			private fun hidden => Integer do
				return 3 if true
				4
			end

			"ok"
		end
	RUBY
end

test "a return inside defined? never runs" do
	assert_equal static_error(<<~RUBY), nil
		fun answer => String do
			defined?(return 1)
			"ok"
		end
	RUBY
end

test "a class with its own === isn’t compared by ancestry" do
	assert_equal static_error(<<~RUBY), nil
		class Stringish
			def self.===(value) = String === value
		end

		fun answer(value = Stringish) => String do
			value
		end
	RUBY
end

test "a literal default of the wrong type" do
	message = static_error(<<~RUBY)
		fun repeat(text = String, count: Integer) => String do |count: "twice"|
			text * count
		end
	RUBY

	assert_equal message, %(example.rb:1: The default for `count` in `repeat` is "twice", which doesn’t match Integer.)
end

test "a default error points at the line the default is on" do
	message = static_error(<<~RUBY)
		fun repeat(text = String, count: Integer) => String do |
			text: "a",
			count: "twice"
		|
			text * count
		end
	RUBY

	assert message.start_with?("example.rb:3: The default for `count`")
end

test "the literal is compared in the file’s own scope, where its refinements apply" do
	processed = Empirical.process("fun answer => String do\n\t:yes\nend\n", with: Empirical::SignatureProcessor)

	assert processed.match?(/StaticCheck\.wrong_value\(.*\) unless ::Empirical::TypeStore::T_\h+_\d+ === \(:yes\)/)
end

test "returning a parameter whose type can never match" do
	message = static_error(<<~RUBY)
		fun name_of(id = Integer) => String do
			id
		end
	RUBY

	assert_equal message, "example.rb:2: `name_of` returns `id`, which is declared as Integer and can never match String."
end

test "returning a parameter that is a subtype or might fit is fine" do
	assert_equal static_error("fun a(x = Integer) => Numeric do\n\tx\nend"), nil
	assert_equal static_error("fun a(x = Numeric) => Integer do\n\tx\nend"), nil
	assert_equal static_error("fun a(x = Comparable) => String do\n\tx\nend"), nil
	assert_equal static_error("fun a(x = _Nilable(String)) => String do\n\tx\nend"), nil
	assert_equal static_error("fun a(x = _Predicate('even', &:even?)) => String do\n\tx\nend"), nil
end

test "unions, nilables and containers are compared by what they could contain" do
	assert static_error("fun a(x = _Nilable(Integer)) => String do\n\tx\nend").include?("can never match String")
	assert static_error("fun a(x = _Union(Integer, Float)) => _Nilable(String) do\n\tx\nend").include?("can never match")
	assert static_error("fun a(xs = [Integer]) => String do\n\txs\nend").include?("declared as _Array(Integer)")
	assert static_error("fun a(x = _Boolean) => Integer do\n\tx\nend").include?("can never match Integer")
end

test "a parameter that is reassigned or shadowed isn’t assumed to keep its type" do
	assert_equal static_error("fun a(x = Integer) => String do\n\tx = x.to_s\n\tx\nend"), nil
	assert_equal static_error("fun a(x = Integer) => String do\n\tx += 1 if false\n\tx\nend"), nil
	assert_equal static_error("fun a(x = Integer) => String do\n\t[1].each { |x| return x.to_s }\n\tx\nend"), nil
end

test "a literal written to a typed ivar" do
	message = static_error(<<~RUBY)
		class Example
			has name: String
			has age: Integer

			def reset
				@age = 0
				@name = :nobody
			end
		end
	RUBY

	assert_equal message, "example.rb:7: `@name` is assigned :nobody, which doesn’t match String."
end

test "one typed ivar written to another" do
	message = static_error(<<~RUBY)
		class Example
			has name: String
			has age: Integer

			def confuse
				@name = @age
			end
		end
	RUBY

	assert_equal message, "example.rb:6: `@name` is assigned `@age`, which is declared as Integer and can never match String."
end

test "returning a typed ivar whose type can never match" do
	message = static_error(<<~RUBY)
		class Example
			has foo: Integer

			fun answer => String do
				@foo
			end
		end
	RUBY

	assert_equal message, "example.rb:5: `answer` returns `@foo`, which is declared as Integer and can never match String."
end

test "returning a typed ivar early" do
	message = static_error(<<~RUBY)
		class Example
			has foo: Integer

			fun answer => String do
				return @foo if rand > 2
				"ok"
			end
		end
	RUBY

	assert_equal message, "example.rb:5: `answer` returns `@foo`, which is declared as Integer and can never match String."
end

test "returning a typed ivar that fits is fine" do
	assert_equal static_error(<<~RUBY), nil
		class Example
			has name: String
			has count: _Nilable(Integer)
			has anything: _Any

			fun name => String do
				@name
			end

			fun count => Integer do
				@count
			end

			fun anything => String do
				@anything
			end
		end
	RUBY
end

test "a parameter written to a typed ivar" do
	message = static_error(<<~RUBY)
		class Example
			has name: String

			fun rename(id = Integer) => void do
				@name = id
			end
		end
	RUBY

	assert_equal message, "example.rb:5: `@name` is assigned `id`, which is declared as Integer and can never match String."
end

test "literals and ivars written to typed ivars inside a fun" do
	literal = static_error(<<~RUBY)
		class Example
			has name: String

			fun reset => void do
				@name = :nobody
			end
		end
	RUBY

	ivar = static_error(<<~RUBY)
		class Example
			has name: String
			has age: Integer

			fun confuse => void do
				@name = @age
			end
		end
	RUBY

	assert_equal literal, "example.rb:5: `@name` is assigned :nobody, which doesn’t match String."
	assert_equal ivar, "example.rb:6: `@name` is assigned `@age`, which is declared as Integer and can never match String."
end

test "ivars in a fun that aren’t known are left to the runtime check" do
	assert_equal static_error(<<~RUBY), nil
		class Example
			fun before_the_prop => String do
				@foo
			end

			has foo: Integer

			fun self.class_level => String do
				@foo
			end

			fun in_a_block(items = Array) => String do
				items.each { return @foo }
				"none"
			end

			fun reassigned(id = Integer) => void do
				id = id.to_s
				@name = id
			end

			has name: String
		end
	RUBY
end

test "writes to a prop inside a fun are checked inline" do
	processed = Empirical.process(<<~RUBY, with: Empirical::IvarProcessor)
		class Example
			has name: String

			fun rename(name = String) => void do
				@name = name
				tap { @name = name }
			end

			fun self.build => void do
				@name = "class level"
			end
		end
	RUBY

	lines = processed.lines

	refute lines[4].include?("= ::Empirical.__check_ivar__(")
	assert lines[4].include?("::Empirical::TypeStore::T_")
	assert lines[5].include?("__check_ivar__")
	assert lines[9].include?("__check_ivar__")
end

test "ivar writes that aren’t known are left to the runtime check" do
	assert_equal static_error(<<~RUBY), nil
		class Example
			has name: String
			has count: Integer

			def set(value) = @name = value
			def self.class_level = @name = 1
			def in_a_block = tap { @count = "many" }
		end
	RUBY
end

test "the class body still evaluates to its last expression" do
	value = Module.new.module_eval(<<~RUBY)
		class Example
			def touch = @name = "a"
			has name: String
		end
	RUBY

	assert_equal value, nil
end

test "checks don’t change line numbers" do
	source = <<~RUBY
		class Example
			has name: String

			def touch = @name = "a"

			fun answer(count = Integer) => Integer do |count: 1|
				return 0 if count.zero?
				count
			end
		end
	RUBY

	processed = Empirical.process(source, with: Empirical::PROCESSORS)

	assert_equal processed.lines.size, source.lines.size
	assert processed.lines[6].include?("return")
end
