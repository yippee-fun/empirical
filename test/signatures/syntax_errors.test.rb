# frozen_string_literal: true

def signature_error(source)
	Empirical.process(source, with: Empirical::SignatureProcessor, path: "example.rb")
	nil
rescue Empirical::TypedSignatureError => error
	error.message
end

test "valid signature" do
	assert_equal signature_error(<<~RUBY), nil
		fun foo => String do
			"Hello"
		end
	RUBY
end

test "errors include the path and line" do
	message = signature_error(<<~RUBY)
		x = 1

		fun foo(a: String) do
		end
	RUBY

	assert message.start_with?("example.rb:3: ")
end

test "missing return type" do
	message = signature_error(<<~RUBY)
		fun foo(a: String) do
		end
	RUBY

	assert message.include?("Expected `fun name(parameters) => ReturnType do ... end`.")
end

test "missing body" do
	message = signature_error("fun foo => String")

	assert message.include?("needs a `do ... end` body")
end

test "braces" do
	message = signature_error("fun foo => String { 1 }")

	assert message.include?("needs a `do ... end` body")
end

test "setter" do
	message = signature_error(<<~RUBY)
		fun name=(value: String) => void do
		end
	RUBY

	assert message.include?("Setters and operators")
end

test "returning a value from a void method" do
	message = signature_error(<<~RUBY)
		fun foo => void do
			return 1
		end
	RUBY

	assert message.start_with?("example.rb:2: ")
	assert message.include?("can’t return a value")
end

test "default for an unknown parameter" do
	message = signature_error(<<~RUBY)
		fun foo(name: String) => String do |nmae: "World"|
			name
		end
	RUBY

	assert message.include?("The default for `nmae` doesn’t match")
end

test "positional block parameter" do
	message = signature_error(<<~RUBY)
		fun foo(name: String) => String do |name|
			name
		end
	RUBY

	assert message.include?("must all be keywords")
end

test "two positional splats" do
	message = signature_error(<<~RUBY)
		fun foo(a: [String], *b) => void do
		end
	RUBY

	assert message.include?("only take one positional splat")
end

test "two keyword splats" do
	message = signature_error(<<~RUBY)
		fun foo(a: { Symbol => String }, **b) => void do
		end
	RUBY

	assert message.include?("only take one keyword splat")
end

test "spread types are reserved" do
	assert signature_error("fun foo(a: [*Type]) => void do\nend").include?("`[*Type]` is reserved")
	assert signature_error("fun foo(a: { **Type }) => void do\nend").include?("`{**Type}` is reserved")
end

test "positional parameter" do
	message = signature_error(<<~RUBY)
		fun foo(a = String) => void do
		end
	RUBY

	assert message.include?("A `fun` can’t take positional parameters. Use a keyword parameter, `a: Type`, or `def`.")
end

test "positional splat after a keyword" do
	message = signature_error(<<~RUBY)
		fun foo(a: String, b: [Integer]) => void do
		end
	RUBY

	assert message.include?("A positional splat must come before keyword parameters.")
end

test "optional positional splat" do
	message = signature_error(<<~RUBY)
		fun foo(a?: [Integer]) => void do
		end
	RUBY

	assert message.include?("A positional splat can’t be optional.")
end

test "default for a positional splat" do
	message = signature_error(<<~RUBY)
		fun foo(a: [Integer]) => void do |a: []|
		end
	RUBY

	assert message.include?("The default for `a` doesn’t match a keyword parameter in the signature.")
end

test "invalid parameter" do
	message = signature_error(<<~RUBY)
		fun foo(1) => void do
		end
	RUBY

	assert message.include?("Invalid parameter `1`")
end

test "reserved word as a splat name" do
	message = signature_error(<<~RUBY)
		fun foo(class: [Integer]) => void do
		end
	RUBY

	assert message.include?("`class` can’t be the name of a splat.")
end

test "untyped splat after a keyword" do
	message = signature_error(<<~RUBY)
		fun foo(name: String, *args) => void do
		end
	RUBY

	assert message.include?("A positional splat must come before keyword parameters.")
end
