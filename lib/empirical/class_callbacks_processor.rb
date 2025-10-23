# frozen_string_literal: true

# Ensure the new callback methods exist on the base classes.
# Developers can define their own callback methods in their classes/modules.
class Module
	def module_defined
	end
end

class Class
	def class_defined
	end
end

class Empirical::ClassCallbacksProcessor < Empirical::BaseProcessor
	# def visit_class_node(node)
	# 	@annotations << [node.end_keyword_loc.start_offset, 0, ";class_defined();"]
	# end

	# def visit_module_node(node)
	# 	@annotations << [node.end_keyword_loc.start_offset, 0, ";module_defined();"]
	# end
end
