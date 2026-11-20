# frozen_string_literal: true

class RuboCop::Cop::Empirical::NoDefs < RuboCop::Cop::Base
	MSG = "Use `fun` method definitions instead of `def` method definitions."

	def on_def(node)
		add_offense(node) unless def_required?(node)
	end

	def on_defs(node)
		add_offense(node) unless def_required?(node)
	end

	# `fun` can’t forward arguments with `...` or take positional parameters.
	private def def_required?(node)
		node.arguments.any? { it.type in :forward_arg | :forward_args | :arg | :optarg }
	end
end
