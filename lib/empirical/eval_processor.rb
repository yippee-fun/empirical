# frozen_string_literal: true

class Empirical::EvalProcessor < Empirical::BaseProcessor
	EVAL_METHODS = Set[:class_eval, :module_eval, :instance_eval, :eval].freeze

	def visit_call_node(node)
		name = node.name

		if EVAL_METHODS.include?(name) && (arguments = node.arguments)
			location = arguments.location

			closing = if arguments.contains_forwarding?
				")), &(::Empirical.__eval_block_from_forwarding__(...))"
			else
				"))"
			end

			if node.receiver
				receiver_local = "__eval_receiver_#{SecureRandom.hex(8)}__"
				receiver_location = node.receiver.location

				@annotations.push(
					[receiver_location.start_character_offset, 0, "(#{receiver_local} = "],
					[receiver_location.end_character_offset, 0, ")"],
					[location.start_character_offset, 0, "*(::Empirical.__process_eval_args__(#{receiver_local}, :#{name}, "],
					[location.end_character_offset, 0, closing]
				)
			else
				@annotations.push(
					[location.start_character_offset, 0, "*(::Empirical.__process_eval_args__(self, :#{name}, "],
					[location.end_character_offset, 0, closing]
				)
			end
		end

		super
	end
end
