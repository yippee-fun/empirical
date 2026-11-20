# frozen_string_literal: true

SOURCES = {
	"simple" => <<~RUBY,
		fun example(name: String, age: Integer) => String do
			__LINE__
		end
	RUBY
	"multi-line signature and types" => <<~RUBY,
		private fun example(
			name: String,
			options: _Hash(
				String,
				Integer
			),
			rest: {
				Symbol => String
			}
		) => _Nilable(
			String
		) do |name: "World"|
			return 1 if false
			__LINE__
		rescue
			__LINE__
		end
		after = __LINE__
	RUBY
	"multi-line default" => <<~RUBY,
		fun example(names: Array) => Array do |names: [
			"a",
			"b",
		]|
			__LINE__
		end
		after = __LINE__
	RUBY
}.freeze

SOURCES.each do |name, source|
	test "#{name}: every line stays on its own line" do
		processed = Empirical.process(source, with: Empirical::SignatureProcessor)

		assert_equal processed.lines.size, source.lines.size

		source.each_line.with_index do |line, index|
			next unless line.include?("__LINE__")

			assert processed.lines[index].include?("__LINE__") do
				"expected `__LINE__` to stay on line #{index + 1}"
			end
		end
	end
end

test "comments in a multi-line type" do
	mod = Module.new do
		extend self

		fun example(
			value: _Union(
				String, # a name
				Integer # or an id
			)
		) => Integer do
			__LINE__
		end
	end

	assert_equal mod.example(value: "a"), __LINE__ - 4
	assert_equal mod.example(value: 1), __LINE__ - 5

	assert_raises Empirical::TypeError do
		mod.example(value: :a)
	end
end

test "a multi-line string in a type or default is rejected" do
	error = assert_raises Empirical::TypedSignatureError do
		Empirical.process(<<~RUBY, with: Empirical::SignatureProcessor)
			fun example(value: String) => String do |value: [
				"a
				b",
			]|
				value
			end
		RUBY
	end

	assert error.message.include?("can’t contain a multi-line string")
end

test "__LINE__ in the body matches the source" do
	mod = Module.new do
		extend self

		fun example(
			options: _Hash(
				String,
				Integer
			)
		) => Integer do
			__LINE__
		end
	end

	assert_equal mod.example(options: {}), __LINE__ - 4
end
