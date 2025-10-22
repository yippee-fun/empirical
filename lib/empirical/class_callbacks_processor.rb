# frozen_string_literal: true

class Empirical::ClassCallbacksProcessor < Empirical::BaseProcessor
	def visit_class_node(node)
		@annotations << [node.end_keyword_loc.start_offset, 0, ";class_defined();"]
	end

	def visit_module_node(node)
		@annotations << [node.end_keyword_loc.start_offset, 0, ";module_defined();"]
	end
end
