# frozen_string_literal: true

module Empirical
	# For internal use only. This method pre-processes arguments to an eval method.
	#: (Object, Symbol, *untyped)
	def self.__process_eval_args__(receiver, method_name, *args)
		method = METHOD_METHOD.bind_call(receiver, method_name)
		owner = method.owner

		source, file = nil

		case method_name
		when :class_eval, :module_eval
			if Module == owner
				source, file = args
			end
		when :instance_eval
			if BasicObject == owner
				source, file = args
			end
		when :eval
			if Kernel == owner
				source, _binding, file = args
			elsif Binding == owner
				source, file = args
			end
		end

		if String === source
			file ||= caller_locations(1, 1).first.path

			if CONFIG.match?(file)
				args[0] = process(source, with: PROCESSORS)
			else
				args[0] = process(source)
			end
		end

		args
	rescue ::NameError
		args
	end

	#: () { () -> void } -> Proc
	def self.__eval_block_from_forwarding__(*, &block)
		block
	end

	class EvalProcessor < Empirical::BaseProcessor
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
end
