# frozen_string_literal: true

class Empirical::IvarProcessor < Empirical::BaseProcessor
	def visit_class_node(node)
		new_context { super }
	end

	def visit_module_node(node)
		new_context { super }
	end

	def visit_call_node(node)
		return super unless node.receiver in Prism::InstanceVariableReadNode
		return super unless node.call_operator_loc.slice == "::"
		receiver_end = node.receiver.location.end_offset
		operator_start = node.call_operator_loc.start_offset

		# Ensure there is a space before the `::`
		return super unless operator_start - receiver_end >= 1

		operator_end = node.call_operator_loc.end_offset
		message_start = node.message_loc.start_offset

		# Ensure there is a space after the `::`
		return super unless message_start - operator_end >= 1

		@context << node.receiver.name

		@annotations << [
			(start = node.location.start_offset),
			node.receiver.location.start_offset - start,
			"(::Empirical::IVAR_TYPE[self] ||= {})[:",
		]

		@annotations << [
			(start = node.receiver.location.end_offset),
			node.message_loc.start_offset - start,
			"] = ",
		]
	end

	def visit_constant_path_node(node)
		return super unless node.parent in Prism::InstanceVariableReadNode

		receiver_end = node.parent.location.end_offset
		operator_start = node.delimiter_loc.start_offset

		# Ensure there is a space before the `::`
		return super unless operator_start - receiver_end >= 1

		operator_end = node.delimiter_loc.end_offset
		name_start = node.name_loc.start_offset

		# Ensure there is a space after the `::`
		return super unless name_start - operator_end >= 1

		@context << node.parent.name

		@annotations << [
			(start = node.location.start_offset),
			node.parent.location.start_offset - start,
			"(::Empirical::IVAR_TYPE[self] ||= {})[:",
		]

		@annotations << [
			(start = node.parent.location.end_offset),
			node.name_loc.start_offset - start,
			"] = ",
		]
	end

	def visit_instance_variable_write_node(node)
		@annotations << [
			node.name_loc.start_offset,
			0,
			"::Empirical::SET_IVAR_METHOD.bind_call(self, :",
		]

		@annotations << [
			(start = node.name_loc.end_offset),
			node.value.location.start_offset - start,
			", ",
		]

		@annotations << [
			node.location.end_offset,
			0,
			")",
		]
	end

	def visit_block_node(node)
		new_context { super }
	end

	def visit_singleton_class_node(node)
		new_context { super }
	end

	def visit_def_node(node)
		new_context { super }
	end

	def visit_if_node(node)
		visit(node.predicate)

		branch { visit(node.statements) }
		branch { visit(node.subsequent) }
	end

	def visit_case_node(node)
		visit(node.predicate)

		node.conditions.each do |condition|
			branch { visit(condition) }
		end

		branch { visit(node.else_clause) }
	end

	def visit_defined_node(node)
		value = node.value

		return if Prism::InstanceVariableReadNode === value

		super
	end

	def visit_instance_variable_read_node(node)
		name = node.name

		unless @context.include?(name)
			location = node.location

			@context << name

			@annotations.push(
				[location.start_character_offset, 0, "(defined?(#{name}) ? "],
				[location.end_character_offset, 0, " : (::Kernel.raise(::Empirical::NameError.new(self, :#{name}))))"]
			)
		end

		super
	end

	private def new_context
		original_context = @context

		@context = Set[]

		begin
			yield
		ensure
			@context = original_context
		end
	end

	private def branch
		original_context = @context
		@context = original_context.dup

		begin
			yield
		ensure
			@context = original_context
		end
	end
end
