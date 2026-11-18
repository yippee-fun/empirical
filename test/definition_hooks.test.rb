# frozen_string_literal: true

HOOK_LOG = []

class HookedBase
	def self.defined
		super
		HOOK_LOG << [:defined, name.split("::").last, instance_methods(false)]
	end

	def self.reopened
		super
		HOOK_LOG << [:reopened, name.split("::").last, instance_methods(false)]
	end
end

class HookedChild < HookedBase
	def first = 1
end

class HookedChild
	def second = 2
end

module HookedModule
	def self.defined
		HOOK_LOG << [:defined, name.split("::").last, instance_methods(false)]
	end

	def helper = 1
end

test "defined fires once the body has run, for the class and its subclasses" do
	assert HOOK_LOG.include?([:defined, "HookedBase", []])
	assert HOOK_LOG.include?([:defined, "HookedChild", [:first]])
end

test "reopened fires when a body closes again" do
	assert HOOK_LOG.include?([:reopened, "HookedChild", [:first, :second]])
	assert_equal HOOK_LOG.count { |hook, name| hook == :defined && name == "HookedChild" }, 1
end

test "modules" do
	assert HOOK_LOG.include?([:defined, "HookedModule", [:helper]])
end

test "redefined fires when a new class takes an existing name, and calls defined by default" do
	log = []
	namespace = Module.new

	source = <<~RUBY
		class Reloadable
			def self.defined = LOG << :defined
			def self.redefined = (LOG << :redefined; super)
		end
	RUBY

	namespace.const_set(:LOG, log)
	namespace.module_eval(source)

	namespace.__send__(:remove_const, :Reloadable)
	namespace.module_eval(source)

	assert_equal log, [:defined, :redefined, :defined]
end

test "Class.new and Module.new" do
	log = []

	base = Class.new do
		define_singleton_method(:defined) { log << instance_methods(false) }
	end

	Class.new(base) do
		def call = 1
	end

	Class.new(base) { def other = 2 }

	assert_equal log, [[], [:call], [:other]]
end

test "the value of a class body is unchanged" do
	namespace = Module.new

	value = namespace.module_eval <<~RUBY
		class BodyValue
			def call = 1
			:last
		end
	RUBY

	empty = namespace.module_eval("class EmptyBody; end")
	singleton = namespace.module_eval("class << BodyValue; self; end")

	assert_equal value, :last
	assert_equal empty, nil
	assert_equal singleton, namespace::BodyValue.singleton_class
end

test "the hook runs after the body’s own rescue" do
	log = []

	Class.new do
		define_singleton_method(:defined) { log << :defined }
		raise "interrupted"
	rescue
		log << :rescued
	end

	assert_equal log, [:rescued, :defined]
end

test "an error in the body skips the hook" do
	log = []

	assert_raises RuntimeError do
		Class.new do
			define_singleton_method(:defined) { log << :defined }
			raise "interrupted"
		end
	end

	assert_equal log, []
end

test "a hook can forbid reopening" do
	namespace = Module.new

	namespace.module_eval <<~RUBY
		class Sealed
			def self.reopened = raise(TypeError, "Sealed can’t be reopened")
		end
	RUBY

	assert_raises TypeError do
		namespace.module_eval("class Sealed; end")
	end
end

test "generated code keeps every line in place" do
	source = <<~RUBY
		class Example < Base
			def call
				__LINE__
			end
		rescue
			nil
		end

		module Helpers; end
		Class.new { foo }
		Module.new do |mod|
			bar
		end
	RUBY

	processed = Empirical.process(source, with: Empirical::DefinitionHooksProcessor)
	block_closing = ";end;rescue ::Exception;__failed__ = true;::Kernel.raise;ensure;::Empirical.__closed__(self) if !__failed__ && ::Module === self;end;"

	assert_equal processed.lines.size, source.lines.size
	assert_equal_ruby processed.gsub(/__empirical_(body|failed)_\d+__/, '__\1__'), <<~RUBY
		class Example < Base;__body__ = begin;
			def call
				__LINE__
			end
		rescue
			nil
		;end;::Empirical.__closed__(self, __FILE__, 1);__body__;end

		module Helpers;__body__ = begin;; ;end;::Empirical.__closed__(self, __FILE__, 9);__body__;end
		Class.new { begin;begin; foo #{block_closing}}
		Module.new do |mod| begin;begin;
			bar
		#{block_closing}end
	RUBY
end

test "the hook runs when a Class.new block is left early with next" do
	log = []

	base = Class.new do
		define_singleton_method(:defined) { log << instance_methods(false) }
	end

	Class.new(base) do
		def early = 1
		next if true
		def late = 2
	end

	assert_equal log, [[], [:early]]
end

test "a shadowed Class constant isn’t treated as a class definition" do
	namespace = Module.new

	result = namespace.module_eval <<~RUBY
		class Class
			def self.new(&block) = "not a module".instance_eval(&block)
		end

		Class.new { upcase }
	RUBY

	assert_equal result, "NOT A MODULE"
end

test "reopening a class that was defined elsewhere fires reopened" do
	log = []

	preexisting = ::Class.new
	preexisting.define_singleton_method(:defined) { log << :defined }
	preexisting.define_singleton_method(:reopened) { log << :reopened }

	Object.const_set(:EmpiricalPreexistingExample, preexisting)
	Object.class_eval("class EmpiricalPreexistingExample; end")
	Object.class_eval("class String; end")

	assert_equal log, [:reopened]
ensure
	Object.__send__(:remove_const, :EmpiricalPreexistingExample)
end

test "a new top-level class fires defined" do
	$empirical_fresh_log = []

	Object.class_eval <<~RUBY
		class EmpiricalFreshExample
			def self.defined = $empirical_fresh_log << :defined
			def self.reopened = $empirical_fresh_log << :reopened
		end

		class EmpiricalFreshExample
		end
	RUBY

	assert_equal $empirical_fresh_log, [:defined, :reopened]
ensure
	Object.__send__(:remove_const, :EmpiricalFreshExample)
end
