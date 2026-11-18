# frozen_string_literal: true

class User
	prop :name, String, reader: :public, writer: :public
	prop :admin, _Boolean, predicate: :public
	prop :secret, String, reader: :private, predicate: :private
	prop :tags, _Array(String)

	def good
		@name = "Hello"
	end

	def bad
		@name = 1
	end

	def untyped
		@other = 1
	end

	def or_write(value)
		@name ||= value
	end

	def operator_write(value)
		@tags = ["a"]
		@tags += value
	end

	def multi_write(name, admin)
		@name, @admin = name, admin
	end

	def in_a_block(value)
		[value].each { |item| @name = item }
	end

	def promote
		@admin = true
	end

	def implicit_array
		@pair = 1, 2
	end

	def splat(list)
		@list = *list
	end

	def rescue_modifier
		@number = Integer("x") rescue 0
	end

	def command_call
		@number = Integer "1"
	end
end

class SubUser < User
	def bad_in_subclass
		@name = 1
	end
end

test "instance variable writes" do
	user = User.new

	user.good
	assert_equal user.name, "Hello"

	error = assert_raises Empirical::TypeError do
		user.bad
	end

	assert error.message.include?("Instance variable @name assigned the wrong type.")
	assert_equal user.name, "Hello"
end

test "untyped ivars in a class with props" do
	assert_equal User.new.untyped, 1
end

test "generated writer/reader" do
	user = User.new
	user.name = "Joel"
	assert_equal user.name, "Joel"

	assert_raises Empirical::TypeError do
		user.name = 1
	end
end

test "predicate" do
	user = User.new
	refute user.admin?

	user.promote
	assert user.admin?
end

test "visibility" do
	assert User.private_instance_methods(false).include?(:secret)
	assert User.private_instance_methods(false).include?(:secret?)
	assert User.public_instance_methods(false).include?(:admin?)
end

test "||= is checked" do
	assert_equal User.new.or_write("Joel"), "Joel"

	assert_raises Empirical::TypeError do
		User.new.or_write(1)
	end
end

test "operator writes are checked" do
	assert_equal User.new.operator_write(["b"]), ["a", "b"]

	assert_raises Empirical::TypeError do
		User.new.operator_write([1])
	end
end

test "multiple assignment is checked" do
	assert_equal User.new.multi_write("Joel", true), ["Joel", true]

	assert_raises Empirical::TypeError do
		User.new.multi_write("Joel", 1)
	end
end

test "writes in blocks are checked" do
	assert_raises Empirical::TypeError do
		User.new.in_a_block(1)
	end
end

test "props are inherited" do
	assert_raises Empirical::TypeError do
		SubUser.new.bad_in_subclass
	end

	assert_raises Empirical::TypeError do
		SubUser.new.name = 1
	end
end

test "a subclass can’t change the type of an inherited prop" do
	error = assert_raises ArgumentError do
		Class.new(User) { prop :name, Integer }
	end

	assert error.message.include?("@name is already declared on")
	assert error.message.include?("with a different type")

	refute_raises do
		Class.new(User) { prop :name, String }
	end
end

test "falsy types are still checked" do
	klass = Class.new do
		prop :nothing, nil, writer: :public
		prop :off, false, writer: :public
	end

	object = klass.new
	object.nothing = nil
	object.off = false

	assert_raises Empirical::TypeError do
		object.nothing = 1
	end

	assert_raises Empirical::TypeError do
		object.off = true
	end
end

test "writes keep their value" do
	user = User.new

	assert_equal user.implicit_array, [1, 2]
	assert_equal user.splat([1, 2]), [1, 2]
	assert_equal user.rescue_modifier, 0
	assert_equal user.command_call, 1
end

test "writes to a prop in its own class are checked inline" do
	processed = Empirical.process(<<~RUBY, with: Empirical::IvarProcessor)
		class Example
			prop :name, String

			def a = @name = "a"
			def b = @other = "b"
			def self.c = @name = "c"
			def d = tap { @name = "d" }
		end
	RUBY

	lines = processed.lines

	assert lines[1].include?("prop :name, ::Empirical::TypeStore.store(")
	refute lines[3].include?("__check_ivar__")
	assert lines[3].include?("::Empirical::TypeStore::T_")
	assert lines[4].include?("@other = ::Empirical.__check_ivar__(self, :@other, (\"b\"))")
	assert lines[5].include?("__check_ivar__")
	assert lines[6].include?("__check_ivar__")
	assert_equal lines.size, 8
end
