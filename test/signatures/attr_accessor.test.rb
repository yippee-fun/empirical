# frozen_string_literal: true

test "attr_accessor with hash rocket syntax - valid assignment" do
	klass = Class.new do
		attr_accessor :name => String

		def initialize
			@name = "Alice"
		end
	end

	instance = klass.new
	assert_equal instance.name, "Alice"

	instance.name = "Bob"
	assert_equal instance.name, "Bob"
end

test "attr_accessor with hash rocket syntax - invalid assignment raises TypeError" do
	klass = Class.new do
		attr_accessor :age => Integer
	end

	instance = klass.new

	assert_raises Empirical::TypeError do
		instance.age = "not a number"
	end
end

test "attr_accessor with keyword syntax - valid assignment" do
	klass = Class.new do
		attr_accessor name: _String(/^[a-z]+$/i)
	end

	instance = klass.new
	instance.name = "Charlie"
	assert_equal instance.name, "Charlie"
end

test "attr_accessor with keyword syntax - invalid assignment raises TypeError" do
	klass = Class.new do
		attr_accessor name: _String(/^[a-z]+$/i)
	end

	instance = klass.new

	assert_raises Empirical::TypeError do
		instance.name = "Charlie1"
	end
end

test "attr_accessor with multiple typed attributes - hash rocket syntax" do
	klass = Class.new do
		attr_accessor :name => String, :age => Integer
	end

	instance = klass.new
	instance.name = "Dave"
	instance.age = 30

	assert_equal instance.name, "Dave"
	assert_equal instance.age, 30
end

test "attr_accessor with multiple typed attributes - keyword syntax" do
	klass = Class.new do
		attr_accessor name: String, age: Integer
	end

	instance = klass.new
	instance.name = "Eve"
	instance.age = 25

	assert_equal instance.name, "Eve"
	assert_equal instance.age, 25
end

test "attr_accessor with multiple typed attributes - keyword syntax - invalid assignment raises TypeError" do
	klass = Class.new do
		attr_accessor name: String, age: Integer
	end

	instance = klass.new
	instance.name = "Eve"
	
	assert_raises Empirical::TypeError do
		instance.age = "25"
	end
end

test "attr_reader validates on read" do
	klass = Class.new do
		attr_reader :id => Integer

		def initialize
			@id = 42
		end
	end

	instance = klass.new
	assert_equal instance.id, 42
end

test "attr_reader raises TypeError when instance variable has wrong type" do
	klass = Class.new do
		attr_reader :id => Integer

		def initialize
			@id = "not an integer"
		end
	end

	instance = klass.new

	assert_raises Empirical::TypeError do
		instance.id
	end
end

test "attr_writer validates on write" do
	klass = Class.new do
		attr_writer :status => Symbol

		def get_status
			@status
		end
	end

	instance = klass.new
	instance.status = :active
	assert_equal instance.get_status, :active
end

test "attr_writer raises TypeError on invalid write" do
	klass = Class.new do
		attr_writer :status => Symbol
	end

	instance = klass.new

	assert_raises Empirical::TypeError do
		instance.status = "not a symbol"
	end
end

test "attr_accessor works alongside typed methods" do
	klass = Class.new do
		attr_accessor :name => String

		fun greet => String do
			"Hello, #{@name}!"
		end
	end

	instance = klass.new
	instance.name = "Frank"
	assert_equal instance.greet, "Hello, Frank!"

	assert_raises Empirical::TypeError do
		instance.name = 123
	end
end

test "multiple attr_accessor declarations in same class" do
	klass = Class.new do
		attr_accessor :first_name => String
		attr_accessor :last_name => String
		attr_accessor :age => Integer
	end

	instance = klass.new
	instance.first_name = "John"
	instance.last_name = "Doe"
	instance.age = 30

	assert_equal instance.first_name, "John"
	assert_equal instance.last_name, "Doe"
	assert_equal instance.age, 30
end

test "attr_ on write error message contains relevant info" do
	klass = Class.new do
		attr_accessor :name => String
	end

	instance = klass.new

	error = assert_raises Empirical::TypeError do
		instance.name = 123
	end

	assert error.message.include?("Attribute name written to with the wrong type")
	assert error.message.include?("Expected: String")
	assert error.message.include?("Actual (Integer): 123")
end

test "attr_ on read error message contains relevant info" do
	klass = Class.new do
		attr_reader :id => Integer

		def initialize
			@id = "wrong"
		end
	end

	instance = klass.new

	error = assert_raises Empirical::TypeError do
		instance.id
	end

	assert error.message.include?("Attribute id read from with the wrong type")
	assert error.message.include?("Expected: Integer")
	assert error.message.include?('Actual (String): "wrong"')
end

test "private attr_accessor maintains visibility" do
	klass = Class.new do
		private

		attr_accessor :secret => String
	end

	instance = klass.new

	error = assert_raises NoMethodError do
		instance.secret = "test"
	end

	assert error.message.include?("private method")
end

test "inline private attr_accessor maintains visibility" do
	klass = Class.new do
		private attr_accessor :secret => String
	end

	instance = klass.new

	error = assert_raises NoMethodError do
		instance.secret = "test"
	end

	assert error.message.include?("private method")
end