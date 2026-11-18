# frozen_string_literal: true

test "private fun checks early returns" do
	mod = Module.new do
		extend self

		private fun example => String do
			return 1 if true
			"Hello"
		end
	end

	assert mod.private_methods.include?(:example)

	assert_raises Empirical::TypeError do
		mod.__send__(:example)
	end
end

test "method-level rescue" do
	mod = Module.new do
		extend self

		fun example => String do
			raise ArgumentError
		rescue ArgumentError
			"rescued"
		end
	end

	assert_equal mod.example, "rescued"
end

test "the value of a rescue clause is type checked" do
	mod = Module.new do
		extend self

		fun example => String do
			raise ArgumentError
		rescue ArgumentError
			1
		end
	end

	assert_raises Empirical::TypeError do
		mod.example
	end
end

test "method-level ensure" do
	log = []

	mod = Module.new do
		extend self

		fun example(log = Array) => String do
			"Hello"
		ensure
			log << :ensured
		end
	end

	assert_equal mod.example(log), "Hello"
	assert_equal log, [:ensured]
end

test "argument type errors aren’t rescued by the method’s own rescue" do
	mod = Module.new do
		extend self

		fun example(name = String) => String do
			name
		rescue TypeError
			"rescued"
		end
	end

	assert_raises Empirical::TypeError do
		mod.example(1)
	end
end

test "empty body" do
	mod = Module.new { extend self }

	mod.module_eval <<~RUBY
		fun example => _Nilable(String) do
		end
	RUBY

	assert_equal mod.example, nil
end

test "return in a block returns from the method and is checked" do
	mod = Module.new do
		extend self

		fun example(items = Array) => String do
			items.each { |item| return item }
			"none"
		end
	end

	assert_equal mod.example(["a"]), "a"

	assert_raises Empirical::TypeError do
		mod.example([1])
	end
end

test "return in a lambda isn’t checked against the method’s return type" do
	mod = Module.new do
		extend self

		fun example => String do
			one = -> { return 1 if true; 0 }
			two = lambda { return 2 if true; 0 }
			(one.call + two.call).to_s
		end
	end

	assert_equal mod.example, "3"
end

test "returning multiple values" do
	mod = Module.new do
		extend self

		fun example => _Tuple(Integer, Integer) do
			return 1, 2 if true
			[0, 0]
		end
	end

	assert_equal mod.example, [1, 2]
end

test "bare return in a typed method returns nil" do
	mod = Module.new do
		extend self

		fun example => _Nilable(String) do
			return if true
			"Hello"
		end
	end

	assert_equal mod.example, nil
end

test "yield" do
	mod = Module.new do
		extend self

		fun example => Integer do
			yield + 1
		end
	end

	assert_equal mod.example { 1 }, 2
end

test "singleton method on self" do
	mod = Module.new do
		fun self.example(name = String) => String do
			name
		end
	end

	assert_equal mod.example("Joel"), "Joel"

	assert_raises Empirical::TypeError do
		mod.example(1)
	end
end

test "BasicObject subclasses" do
	klass = Class.new(BasicObject) do
		fun example(class: ::String) => ::String do
			return "early" if false
			::Kernel.binding.local_variable_get(:class)
		end

		fun nothing => never do
			nil
		end
	end

	assert_equal klass.new.example(class: "a"), "a"

	assert_raises Empirical::TypeError do
		klass.new.example(class: 1)
	end

	assert_raises Empirical::NeverError do
		klass.new.nothing
	end
end

test "type errors work on objects that override #method" do
	klass = Class.new do
		def method = "GET"

		fun example(name = String) => String do
			name
		end
	end

	assert_raises Empirical::TypeError do
		klass.new.example(1)
	end
end
