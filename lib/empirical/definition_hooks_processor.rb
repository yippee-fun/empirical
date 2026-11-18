# frozen_string_literal: true

# Calls `Empirical.__closed__(self)` at the end of every class and module body, which fires the
# `defined`, `reopened` and `redefined` hooks. The body is wrapped in `begin ... end` so the hook runs
# after any `rescue` or `ensure` of its own, and its value is kept so the class expression still
# evaluates to what it did before.
class Empirical::DefinitionHooksProcessor < Empirical::BaseProcessor
	HOOK = "::Empirical.__closed__(self)"

	def visit_class_node(node)
		header = node.superclass || node.constant_path
		wrap_body(header.location.end_offset, node.end_keyword_loc.start_offset)

		super
	end

	def visit_module_node(node)
		wrap_body(node.constant_path.location.end_offset, node.end_keyword_loc.start_offset)

		super
	end

	# `Class.new do ... end` and `Module.new do ... end`
	def visit_call_node(node)
		if anonymous_definition?(node)
			block = node.block
			parameters = block.parameters

			start_offset = if Prism::BlockParametersNode === parameters
				parameters.location.end_offset
			else
				block.opening_loc.end_offset
			end

			wrap(start_offset, block.closing_loc.start_offset, " begin;", ";end;#{HOOK};")
		end

		super
	end

	private def wrap_body(start_offset, end_offset)
		value = "__empirical_body_#{start_offset}__"

		wrap(start_offset, end_offset, ";#{value} = begin;", ";end;#{HOOK};#{value};")
	end

	private def anonymous_definition?(node)
		return false unless node.name == :new && Prism::BlockNode === node.block

		node.receiver in Prism::ConstantReadNode[name: :Class | :Module] |
			Prism::ConstantPathNode[parent: nil, name: :Class | :Module]
	end
end
