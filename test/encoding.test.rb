# frozen_string_literal: true

test "multibyte characters before an ivar read" do
	processed = Empirical.process(<<~RUBY, with: Empirical::IvarProcessor)
		def foo
			"日本語"; @foo
		end
	RUBY

	assert_equal_ruby processed, <<~RUBY
		def foo
			"日本語"; (defined?(@foo) ? @foo : (::Kernel.raise(::Empirical::NameError.new(self, :@foo))))
		end
	RUBY
end

test "multibyte characters before an eval" do
	processed = Empirical.process(<<~RUBY)
		"é"; eval("1")
	RUBY

	assert_equal_ruby processed, <<~RUBY
		"é"; eval(*(::Empirical.__process_eval_args__(self, :eval, "1")))
	RUBY
end

test "binary source keeps the encoding of the file" do
	processed = Empirical.process(%(x = "é"; @foo).b, with: Empirical::IvarProcessor)

	assert_equal processed.encoding, Encoding::UTF_8
	assert processed.valid_encoding?
end

test "binary source honours a magic encoding comment" do
	processed = Empirical.process("# encoding: iso-8859-1\nx = 1".b)

	assert_equal processed.encoding, Encoding::ISO_8859_1
end
