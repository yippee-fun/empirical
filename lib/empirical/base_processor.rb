# frozen_string_literal: true

class Empirical::BaseProcessor < Prism::Visitor
	EVAL_METHODS = Set[:class_eval, :module_eval, :instance_eval, :eval].freeze

	def initialize(annotations:)
		@context = Set[]
		@annotations = annotations
	end
end
