# frozen_string_literal: true

class Person < Literal::Struct
	prop :name, String
	prop :age, _Nilable(Integer), default: nil

	def rename(name)
		@name = name
	end

	def age_in_a_block(age)
		tap { @age = age }
	end

	def undeclared
		@nickname = "J"
	end
end

class Employee < Person
	prop :role, Symbol

	def promote(role)
		@role = role
	end

	def rename_from_subclass(name)
		@name = name
	end
end

class Money < Literal::Data
	prop :amount, Integer

	def doubled = Money.new(amount: @amount * 2)
end

class Plain
	extend Literal::Properties

	prop :value, Integer, :positional, reader: :public

	def bump = @value += 1
end

test "Literal still builds the initializer and accessors" do
	person = Person.new(name: "Joel")

	assert_equal person.name, "Joel"
	assert_equal person.to_h, { name: "Joel", age: nil }
	assert_equal Plain.new(1).value, 1
	assert_equal Money.new(amount: 2).doubled.amount, 4
end

test "writes to a Literal prop inside a method are checked" do
	person = Person.new(name: "Joel")

	assert_equal person.rename("Stephen"), "Stephen"

	assert_raises Empirical::TypeError do
		person.rename(1)
	end

	assert_raises Empirical::TypeError do
		person.age_in_a_block("42")
	end

	assert_equal Plain.new(1).bump, 2
end

test "Literal props are inherited" do
	employee = Employee.new(name: "Joel", role: :engineer)

	assert_equal employee.promote(:manager), :manager
	assert_equal employee.rename_from_subclass("Stephen"), "Stephen"

	assert_raises Empirical::TypeError do
		employee.promote("manager")
	end

	assert_raises Empirical::TypeError do
		employee.rename_from_subclass(1)
	end
end

test "undeclared ivars are still banned in Literal classes" do
	assert_raises Empirical::UndeclaredInstanceVariableError do
		Person.new(name: "Joel").undeclared
	end
end

test "a prop added when a class is reopened is recognised" do
	namespace = Module.new

	namespace.module_eval <<~RUBY
		class Reopened < Literal::Struct
			prop :first, _Nilable(String)

			def set_second(value) = tap { @second = value }
		end
	RUBY

	assert_raises Empirical::UndeclaredInstanceVariableError do
		namespace::Reopened.new.set_second(1)
	end

	namespace.module_eval <<~RUBY
		class Reopened
			prop :second, _Nilable(Integer)
		end
	RUBY

	assert_equal namespace::Reopened.new.set_second(1).second, 1
end

test "Empirical’s prop takes the same accessor options as Literal’s" do
	klass = Class.new do
		prop :name, String, reader: :public, writer: false, predicate: false
	end

	assert klass.public_method_defined?(:name)
	refute klass.method_defined?(:name=)
end
