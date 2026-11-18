# frozen_string_literal: true

test "parameter types and return type" do
	mod = Module.new do
		extend self

		fun example(name = String, tags = [Symbol], admin?: _Boolean, options: { Symbol => Integer }, &block) => Integer do
			1
		end
	end

	method = mod.method(:example)

	assert_equal method.parameter_types.transform_values(&:inspect), {
		name: "String",
		tags: "_Array(Symbol)",
		admin: "_Nilable(_Boolean)",
		options: "_Hash(Symbol, Integer)",
	}

	assert_equal method.return_type, Integer
end

test "unbound methods" do
	klass = Class.new do
		fun example(name: String) => String do
			name
		end
	end

	method = klass.instance_method(:example)

	assert_equal method.parameter_types, { name: String }
	assert_equal method.return_type, String
end

test "itself" do
	klass = Class.new do
		fun example => itself do
			self
		end
	end

	assert_equal klass.instance_method(:example).return_type, Empirical::Itself
end

test "void and never" do
	mod = Module.new do
		extend self

		fun log => void do
			nil
		end

		fun fail! => never do
			raise "Failed"
		end
	end

	assert_equal mod.method(:log).parameter_types, {}
	assert_equal mod.method(:log).return_type, _Void
	assert_equal mod.method(:fail!).return_type, _Never
end

test "multi-line signatures" do
	mod = Module.new do
		extend self

		private fun example(
			name = String
		) => String do |name: "World"|
			name
		end
	end

	assert_equal mod.method(:example).parameter_types, { name: String }
	assert_equal mod.method(:example).return_type, String
end

test "singleton methods" do
	klass = Class.new do
		fun self.build(name: String) => String do
			name
		end
	end

	assert_equal klass.method(:build).parameter_types, { name: String }
	assert_equal klass.method(:build).return_type, String
end

test "aliases" do
	klass = Class.new do
		fun example => String do
			"example"
		end

		alias_method :other, :example
	end

	assert_equal klass.instance_method(:other).return_type, String
end

test "methods defined with def" do
	klass = Class.new do
		def example(name) = name
	end

	assert_equal klass.instance_method(:example).parameter_types, nil
	assert_equal klass.instance_method(:example).return_type, nil
	assert_equal 1.method(:+).return_type, nil
end

test "a def that replaces a fun" do
	klass = Class.new do
		fun example => String do
			"example"
		end

		def example = "example"
	end

	assert_equal klass.instance_method(:example).return_type, nil
end

test "methods defined in eval" do
	klass = Class.new

	klass.class_eval <<~RUBY, __FILE__, __LINE__ + 1
		fun example(count = Integer) => Integer do
			count
		end
	RUBY

	assert_equal klass.instance_method(:example).parameter_types, { count: Integer }
	assert_equal klass.instance_method(:example).return_type, Integer
end
