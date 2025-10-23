# frozen_string_literal: true

class RuboCop::Cop::Empirical::NoDefs < RuboCop::Cop::Base
	MSG = "Use `fun` method definitions instead of `def` method definitions."

	def on_def(node)
		add_offense(node)
	end

	def on_defs(node)
		add_offense(node)
	end
end
