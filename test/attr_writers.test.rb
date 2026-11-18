# frozen_string_literal: true

class Account
	prop :name, String
	prop :age, Integer
	prop :notes, _Any

	attr_writer :name
	attr_accessor :age, :notes

	protected attr_writer :token

	private

	attr_writer :secret

	prop :token, String
	prop :secret, String
end

class SubAccount < Account
	prop :level, Integer

	attr_accessor :level
end

test "attr_writer on a typed ivar is checked" do
	account = Account.new
	account.name = "Joel"

	assert_raises Empirical::TypeError do
		account.name = 1
	end
end

test "attr_accessor on a typed ivar is checked and still reads" do
	account = Account.new
	account.age = 30

	assert_equal account.age, 30

	assert_raises Empirical::TypeError do
		account.age = "30"
	end
end

test "an attribute declared as _Any takes anything" do
	account = Account.new
	account.notes = [1, "two"]

	assert_equal account.notes, [1, "two"]
end

test "a writer for an undeclared ivar raises when it’s called" do
	klass = Class.new do
		attr_writer :undeclared
	end

	assert_raises Empirical::UndeclaredInstanceVariableError do
		klass.new.undeclared = 1
	end
end

test "a writer returns the assigned value" do
	assert_equal Account.new.public_send(:age=, 30), 30
end

test "writers keep their visibility" do
	assert Account.public_method_defined?(:name=)
	assert Account.public_method_defined?(:age=)
	assert Account.protected_method_defined?(:token=)
	assert Account.private_method_defined?(:secret=)
end

test "a prop declared after the writer is still checked" do
	assert_raises Empirical::TypeError do
		Account.new.__send__(:secret=, 1)
	end
end

test "subclasses" do
	account = SubAccount.new
	account.level = 1

	assert_raises Empirical::TypeError do
		account.level = "1"
	end

	assert_raises Empirical::TypeError do
		account.name = 1
	end
end

test "attr_writer still returns the method names" do
	names = nil

	Class.new do
		names = attr_accessor :a, :b
	end

	assert_equal names, [:a, :a=, :b, :b=]
end

test "generated code" do
	processed = Empirical.process(<<~RUBY, with: Empirical::IvarProcessor)
		private attr_writer :name
		attr_accessor(:age)
		attr_reader :id
	RUBY

	assert_equal_ruby processed, <<~RUBY
		private ::Empirical.__check_writers__(self, (attr_writer :name))
		::Empirical.__check_writers__(self, (attr_accessor(:age)))
		attr_reader :id
	RUBY
end
