# frozen_string_literal: true

# Checks the compiler arranges to run once, when a method or class is defined, for mistakes it can
# see in the source. They use the real type objects, so they are exact for any type.
module Empirical::StaticCheck
	extend self

	# A literal that is about to flow into a typed slot.
	def value(expected, value, file, line, description)
		return if expected === value

		raise Empirical::StaticTypeError, "#{file}:#{line}: #{description} #{value.inspect}, which doesn’t match #{expected.inspect}."
	end

	# Something with a declared type that is about to flow into a typed slot. A subtype always fits.
	# Otherwise it could still fit at runtime (a Numeric that happens to be an Integer), so this only
	# raises when no value of the one type could ever match the other.
	def type(expected, actual, file, line, description)
		return if Literal.subtype?(actual, expected)
		return unless disjoint?(expected, actual)

		raise Empirical::StaticTypeError, "#{file}:#{line}: #{description}, which is declared as #{actual.inspect} and can never match #{expected.inspect}."
	end

	# Returns the type after running the checks in the block.
	def after(type)
		yield
		type
	end

	private def disjoint?(expected, actual)
		expected = alternatives(expected)
		actual = alternatives(actual)

		return false unless expected && actual

		expected.product(actual).all? { |a, b| apart?(a, b) }
	end

	# Breaks a type into the classes and exact values it could match, or nil when that isn’t known.
	# A class can stand in for a narrower type: if the classes can’t overlap, neither can the types.
	private def alternatives(type)
		case type
		in nil | true | false
			[[:value, type]]
		in Class
			# A class that defines its own `===` can match things that aren’t its instances.
			return unless Empirical::METHOD_METHOD.bind_call(type, :===).owner.equal?(Module)

			[[:class, type]]
		in Literal::Types::BooleanType
			[[:value, true], [:value, false]]
		in Literal::Types::NilableType
			inner = alternatives(type.type)
			inner && [*inner, [:value, nil]]
		in Literal::Types::UnionType
			members = type.types.map { |member| alternatives(member) }
			members.all? && [*members.flatten(1), *type.primitives.map { |primitive| [:value, primitive] }]
		in Literal::Types::ArrayType | Literal::Types::TupleType
			[[:class, Array]]
		in Literal::Types::HashType | Literal::Types::MapType
			[[:class, Hash]]
		in Literal::Types::SetType
			[[:class, Set]]
		else
			nil
		end
	end

	private def apart?(a, b)
		case [a, b]
		in [[:class, first], [:class, second]]
			!(first <= second) && !(second <= first)
		in [[:class, klass], [:value, value]]
			!(klass === value)
		in [[:value, value], [:class, klass]]
			!(klass === value)
		in [[:value, first], [:value, second]]
			first != second
		end
	end
end
