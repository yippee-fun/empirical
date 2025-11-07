# frozen_string_literal: true

# test do
# 	processed = Empirical.process(<<~RUBY, with: Empirical::PROCESSORS)
# 		fun example(name: String) => String do |name: "World"|

# 		end
# 	RUBY

# 	puts processed
# end

test "optional keyword argument" do
	mod = Module.new do
		extend self

		fun example(name: String) => String do |name: "World"|
			"Hello #{name}!"
		end
	end

	assert_equal "Hello World!", mod.example
	assert_equal "Hello Alice!", mod.example(name: "Alice")
end

test "optional positional argument" do
	mod = Module.new do
		extend self

		fun example(name = String) => String do |name: "World"|
			"Hello #{name}!"
		end
	end

	assert_equal "Hello World!", mod.example
	assert_equal "Hello Alice!", mod.example("Alice")
end
