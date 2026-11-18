# frozen_string_literal: true

# Each method reads @missing somewhere that never runs, then reads it for real.
class SkippedReads
	def and_operator
		false && @missing
		@missing
	end

	def or_operator
		true || @missing
		@missing
	end

	def unless_modifier
		@missing unless true
		@missing
	end

	def while_loop
		while false do @missing end
		@missing
	end

	def until_loop
		until true do @missing end
		@missing
	end

	def for_loop
		for _ in [] do @missing end
		@missing
	end

	def or_assignment
		value = 1
		value ||= @missing
		@missing
	end

	def safe_navigation
		nil&.then(@missing)
		@missing
	end

	def rescued_body
		begin
			interrupt
			@missing
		rescue
			nil
		end

		@missing
	end

	def rescue_modifier
		(interrupt; @missing) rescue nil
		@missing
	end

	def lambda_body
		-> { @missing }
		@missing
	end

	def case_match
		case 1
		in 2 then @missing
		in 1 then nil
		end

		@missing
	end

	def defined_expression
		defined?(@missing.foo)
		@missing
	end

	def value_of_a_write
		@other = @missing
	end

	def write_in_a_skipped_default(value = (@missing = 1))
		@missing
	end

	def write_in_a_skipped_keyword_default(value: (@missing = 1))
		@missing
	end

	def ensure_after_interrupted_body
		interrupt
		@missing
	ensure
		@missing
	end

	private def interrupt
		raise "interrupted"
	end
end

ARGUMENTS = {
	write_in_a_skipped_default: [[10], {}],
	write_in_a_skipped_keyword_default: [[], { value: 10 }],
}.freeze

SkippedReads.public_instance_methods(false).each do |method_name|
	test "read after a skipped read is still guarded: #{method_name}" do
		positional, keywords = ARGUMENTS.fetch(method_name, [[], {}])

		assert_raises Empirical::NameError do
			SkippedReads.new.public_send(method_name, *positional, **keywords)
		end
	end
end

test "a read after a write isn’t guarded again" do
	processed = Empirical.process(<<~RUBY, with: Empirical::IvarProcessor)
		def foo
			@foo = 1
			@foo
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo
			@foo = ::Empirical.__check_ivar__(self, :@foo, (1))
			@foo
		end
	RUBY
end

test "a read after a conditional write is guarded" do
	processed = Empirical.process(<<~RUBY, with: Empirical::IvarProcessor)
		def foo
			@foo = 1 if bar
			@foo
		end
	RUBY

	assert processed.lines[2].include?("defined?(@foo)")
end

test "eval of an ivar nests the guard inside the eval wrapper" do
	object = Class.new do
		def initialize = @code = "1 + 1"
		def call = eval(@code)
	end

	assert_equal object.new.call, 2
end
