# frozen_string_literal: true

# Calls `Empirical.__closed__` at the end of every class and module body, which fires the `defined`,
# `reopened` and `redefined` hooks. The body is wrapped in `begin ... end` so the hook runs after any
# `rescue` or `ensure` of its own, and its value is kept so the class expression still evaluates to
# what it did before.
class Empirical::DefinitionHooksProcessor < Empirical::BaseProcessor
	def visit_class_node(node)
		header = node.superclass || node.constant_path
		wrap_body(node, header.location.end_offset)

		super
	end

	def visit_module_node(node)
		wrap_body(node, node.constant_path.location.end_offset)

		super
	end

	# `Class.new do ... end` and `Module.new do ... end`
	def visit_call_node(node)
		wrap_block(node.block) if anonymous_definition?(node)

		super
	end

	# The file and line let the hook tell a new definition from the reopening of a class that
	# was defined somewhere Empirical didn’t see.
	private def wrap_body(node, start_offset)
		value = "__empirical_body_#{start_offset}__"
		hook = "::Empirical.__closed__(self, __FILE__, #{node.location.start_line})"

		wrap(start_offset, node.end_keyword_loc.start_offset, ";#{value} = begin;", ";end;#{hook};#{value};")
	end

	# A block can be left early with `next`, so the hook runs from an `ensure`, unless the body raised.
	# `Class` and `Module` could be other constants in this scope, so it also checks what `self` is.
	private def wrap_block(block)
		parameters = block.parameters

		start_offset = if Prism::BlockParametersNode === parameters
			parameters.location.end_offset
		else
			block.opening_loc.end_offset
		end

		failed = "__empirical_failed_#{start_offset}__"

		wrap(
			start_offset,
			block.closing_loc.start_offset,
			" begin;begin;",
			";end;rescue ::Exception;#{failed} = true;::Kernel.raise;ensure;::Empirical.__closed__(self) if !#{failed} && ::Module === self;end;"
		)
	end

	private def anonymous_definition?(node)
		return false unless node.name == :new && Prism::BlockNode === node.block

		node.receiver in Prism::ConstantReadNode[name: :Class | :Module] |
			Prism::ConstantPathNode[parent: nil, name: :Class | :Module]
	end
end
