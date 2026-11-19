# frozen_string_literal: true

class Empirical::UndeclaredInstanceVariableError < ::NameError
	def initialize(object, name)
		declaration = "has #{name.name.delete_prefix('@')}: Type"

		if Module === object
			super("Undeclared instance variable `#{name}` on #{object.inspect} itself. Declare it with `class << self; #{declaration}; end`.")
		else
			owner = Empirical::CLASS_METHOD.bind_call(object)
			super("Undeclared instance variable `#{name}` on an instance of #{owner.inspect}. Declare it with `#{declaration}`.")
		end
	end
end
