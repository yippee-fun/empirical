# frozen_string_literal: true

def generated(source)
	Empirical.process(source, with: Empirical::SignatureProcessor).gsub(/T_\h{12}_\d+/, "T")
end

test "void method with a required keyword" do
	assert_equal_ruby generated(<<~RUBY), <<~RUBY
		fun greet(name: String) => void do
			puts name
		end
	RUBY
		def greet(name:);::Kernel.raise(::Empirical::TypeError.argument_type_error(name: :name, value: name, expected: ::Empirical::TypeStore::T, method_name: :greet, context: self)) unless ::Empirical::TypeStore::T === name;begin;
			puts name
		;end;::Empirical::Void;end;::Empirical::TypeStore.store(:T, (String));
	RUBY
end

test "typed return with an early return" do
	assert_equal_ruby generated(<<~RUBY), <<~RUBY
		private fun answer => Integer do
			return 1 if true
			2
		end
	RUBY
		private def answer;__empirical_return__ = begin;
			return (__empirical_return__ = ( 1);(::Kernel.raise(::Empirical::TypeError.return_type_error(value: __empirical_return__, expected: ::Empirical::TypeStore::T, method_name: :answer, context: self)) unless ::Empirical::TypeStore::T === __empirical_return__);__empirical_return__) if true
			2
		;end;::Kernel.raise(::Empirical::TypeError.return_type_error(value: __empirical_return__, expected: ::Empirical::TypeStore::T, method_name: :answer, context: self)) unless ::Empirical::TypeStore::T === __empirical_return__;__empirical_return__;end;::Empirical::TypeStore.store(:T, (Integer));
	RUBY
end

test "parameters keep their Ruby shape" do
	signature = generated(<<~RUBY).lines.first[/\Adef .*?\)/]
		fun example(a = String, b = Integer, c = [Symbol], d: String, e?: Integer, f: { Symbol => String }, &block) => void do |b: 1, d: "x"|
		end
	RUBY

	assert_equal signature, %(def example(a, b = 1, *c, d: "x", e: nil, **f, &block))
end

test "the same source always generates the same code" do
	source = "fun example(a = String) => String do\n\ta\nend\n"

	assert_equal(
		Empirical.process(source, with: Empirical::SignatureProcessor, path: "a.rb"),
		Empirical.process(source, with: Empirical::SignatureProcessor, path: "a.rb"),
	)
end
