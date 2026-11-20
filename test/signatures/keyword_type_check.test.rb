# frozen_string_literal: true

test "required keyword stays a keyword" do
	mod = Module.new do
		extend self

		fun example(name: String) => String do
			name
		end
	end

	assert_equal mod.method(:example).parameters, [[:keyreq, :name]]
	assert_equal mod.example(name: "Joel"), "Joel"
end

test "raises when given the wrong keyword type" do
	mod = Module.new do
		extend self

		fun example(name: String) => String do
			name
		end
	end

	error = assert_raises Empirical::TypeError do
		mod.example(name: 1)
	end

	assert error.message.include?("wrong type for the argument name")
end

test "raises when a required keyword is missing" do
	mod = Module.new do
		extend self

		fun example(name: String) => String do
			name
		end
	end

	assert_raises ArgumentError do
		mod.example
	end
end

test "required and optional keywords" do
	mod = Module.new do
		extend self

		fun example(greeting: String, name: String, punctuation?: String) => String do
			"#{greeting} #{name}#{punctuation}"
		end
	end

	assert_equal mod.method(:example).parameters, [[:keyreq, :greeting], [:keyreq, :name], [:key, :punctuation]]
	assert_equal mod.example(greeting: "Hello", name: "Joel"), "Hello Joel"
	assert_equal mod.example(greeting: "Hello", name: "Joel", punctuation: "!"), "Hello Joel!"
end

test "keyword named after a reserved word" do
	mod = Module.new do
		extend self

		fun example(class: String) => String do
			binding.local_variable_get(:class)
		end
	end

	assert_equal mod.example(class: "button"), "button"

	assert_raises Empirical::TypeError do
		mod.example(class: 1)
	end
end
