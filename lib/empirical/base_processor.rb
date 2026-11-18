# frozen_string_literal: true

require "digest"

class Empirical::BaseProcessor < Prism::Visitor
	EVAL_METHODS = Set[:class_eval, :module_eval, :instance_eval, :eval].freeze

	def initialize(annotations:, source:, path: nil)
		@context = Set[]
		@annotations = annotations
		@source = source
		@path = path
	end

	# Inserts `opening` and `closing` around a range of the source. When wrappers share a boundary they nest
	# by size, and wrappers around exactly the same range nest in the order they were added, outermost first.
	private def wrap(start_offset, end_offset, opening, closing)
		sequence = @annotations.size

		@annotations.push(
			[start_offset, 0, opening, [2, -end_offset, sequence]],
			[end_offset, 0, closing, [0, -start_offset, -sequence]]
		)
	end

	# Identifies this file in the names of stored types, so the same source always generates the same code.
	private def site
		@site ||= Digest::SHA256.hexdigest(@path || @source)[0, 12]
	end
end
