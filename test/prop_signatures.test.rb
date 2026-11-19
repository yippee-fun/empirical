# frozen_string_literal: true

class User
	prop :name, String, reader: :public, writer: :public
	prop :admin, _Boolean, predicate: :public
	prop :secret, String, reader: :private, predicate: :private
	prop :tags, _Array(String)
	prop :pair, Array
	prop :list, Array
	prop :number, Integer

	def good
		@name = "Hello"
	end

	def bad
		@name = 1.to_i
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

	def nested_multi_write(name, admin)
		(@name, @admin), @number = [name, admin], 1
	end

	def implicit_rest_multi_write(name)
		@name, = name, nil
	end

	def splat_multi_write(*names)
		@name, *@tags = *names
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

class Swapper
	prop :first, String
	prop :second, String

	def call
		kept = (@first = "a")
		@second = "b"
		@first, @second = @second, kept
		[kept, @first, @second]
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

test "writing an undeclared ivar raises" do
	error = assert_raises Empirical::UndeclaredInstanceVariableError do
		User.new.untyped
	end

	assert error.message.include?("Undeclared instance variable `@other` on an instance of")
	assert error.message.include?("Declare it with `prop :other, Type`.")
end

test "writing an undeclared ivar raises in a class with no props" do
	klass = Class.new do
		def initialize = @name = "Joel"
	end

	assert_raises Empirical::UndeclaredInstanceVariableError do
		klass.new
	end
end

test "objects that override #class are still checked against their real class" do
	klass = Class.new do
		prop :name, String

		def class = Integer
		def set(value) = tap { @name = value }
	end

	assert_equal klass.new.set("Joel").instance_variable_get(:@name), "Joel"

	assert_raises Empirical::TypeError do
		klass.new.set(1)
	end
end

test "modules declare the ivars they write" do
	mod = Module.new do
		prop :count, Integer

		def increment = @count = (defined?(@count) ? @count : 0) + 1
	end

	klass = Class.new { include mod }

	assert_equal klass.new.increment, 1
end

test "class-level ivars are declared on the singleton class" do
	klass = Class.new do
		class << self
			prop :registry, Hash
		end

		@registry = {}

		def self.register(key) = @registry[key] = true
		def self.undeclared = @other = 1
		def self.wrong = @registry = []
	end

	subclass = Class.new(klass) do
		@registry = { inherited: true }
	end

	assert_equal klass.register(:a), true
	assert_equal subclass.instance_variable_get(:@registry), { inherited: true }

	error = assert_raises Empirical::UndeclaredInstanceVariableError do
		klass.undeclared
	end

	assert error.message.include?("Declare it with `class << self; prop :other, Type; end`.")

	assert_raises Empirical::TypeError do
		klass.wrong
	end
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

test "nested targets in a multiple assignment are checked" do
	User.new.nested_multi_write("Joel", true)

	assert_raises Empirical::TypeError do
		User.new.nested_multi_write("Joel", 1)
	end
end

test "a multiple assignment with an implicit rest is checked" do
	User.new.implicit_rest_multi_write("Joel")

	assert_raises Empirical::TypeError do
		User.new.implicit_rest_multi_write(1)
	end
end

test "a splat target in a multiple assignment is checked" do
	User.new.splat_multi_write("Joel", "a")

	assert_raises Empirical::TypeError do
		User.new.splat_multi_write("Joel", 1)
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

test "inline checks don’t share a temporary" do
	assert_equal Swapper.new.call, ["a", "b", "a"]

	processed = Empirical.process(<<~RUBY, with: Empirical::IvarProcessor)
		class Example
			prop :name, String

			def call
				@name = "a"
				@name = "b"
			end
		end
	RUBY

	assert_equal processed.scan(/__empirical_ivar_\d+__ = /).uniq.size, 2
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

	assert lines[1].start_with?("\tprop :name, ::Empirical::StaticCheck.after(::Empirical::TypeStore.store(")
	assert lines[1].include?(%[("a"), __FILE__, 4, "`@name` is assigned")])
	refute lines[3].include?("__check_ivar__")
	assert lines[3].include?("::Empirical::TypeStore::T_")
	assert lines[4].include?("@other = ::Empirical.__check_ivar__(self, :@other, (\"b\"))")
	assert lines[5].include?("__check_ivar__")
	assert lines[6].include?("__check_ivar__")
	assert_equal lines.size, 8
end
