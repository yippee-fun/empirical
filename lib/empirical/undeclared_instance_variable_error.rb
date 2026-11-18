# frozen_string_literal: true

class Empirical::UndeclaredInstanceVariableError < ::NameError
	def initialize(object, name)
		prop = "prop :#{name.name.delete_prefix('@')}, Type"

		if Module === object
			super("Undeclared instance variable `#{name}` on #{object.inspect} itself. Declare it with `class << self; #{prop}; end`.")
		else
			owner = Empirical::CLASS_METHOD.bind_call(object)
			super("Undeclared instance variable `#{name}` on an instance of #{owner.inspect}. Declare it with `#{prop}`.")
		end
	end
end
