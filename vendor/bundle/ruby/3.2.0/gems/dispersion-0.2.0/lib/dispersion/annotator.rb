# frozen_string_literal: true

require "prism"

module Dispersion
	class Annotator < Prism::Visitor
		def self.call(code)
			new(code).call
		end

		def initialize(code)
			@code = code
			@annotations = []
		end

		def call
			@prev_end = 0
			parsed = Prism.parse(@code)
			parsed.comments.each { |c| visit_comment(c) }
			visit(parsed.value)

			@annotations.sort_by(&:first)
		end

		def highlight(token, loc)
			return unless loc
			return if loc.start_line == loc.end_line && loc.start_column == loc.end_column

			@annotations << [loc.start_offset, loc.end_offset, token].freeze
		end

		def visit_comment(node)
			highlight Tokens::COMMENT, node.location
		end

		def visit_def_node(node)
			highlight Tokens::KEYWORD, node.def_keyword_loc
			highlight Tokens::FUNCTION, node.name_loc
			highlight Tokens::PUNCTUATION, node.lparen_loc
			highlight Tokens::PUNCTUATION, node.rparen_loc
			highlight Tokens::KEYWORD, node.end_keyword_loc
			super
		end

		def visit_local_variable_write_node(node)
			highlight Tokens::LOCAL_VARIABLE, node.name_loc
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_local_variable_read_node(node)
			highlight Tokens::LOCAL_VARIABLE, node.location
			super
		end

		def visit_instance_variable_write_node(node)
			highlight Tokens::INSTANCE_VARIABLE, node.name_loc
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_instance_variable_and_write_node(node)
			highlight Tokens::INSTANCE_VARIABLE, node.name_loc
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_instance_variable_or_write_node(node)
			highlight Tokens::INSTANCE_VARIABLE, node.name_loc
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_instance_variable_read_node(node)
			highlight Tokens::INSTANCE_VARIABLE, node.location
			super
		end

		def visit_constant_read_node(node)
			highlight Tokens::CONSTANT, node.location
			super
		end

		def visit_class_node(node)
			highlight Tokens::KEYWORD, node.class_keyword_loc
			highlight Tokens::KEYWORD, node.end_keyword_loc
			super
		end

		def visit_call_node(node)
			unless node.name in :[] | :[]=
				highlight Tokens::FUNCTION, node.message_loc
			end

			super
		end

		def visit_string_node(node)
			highlight Tokens::STRING, node.location
			super
		end

		def visit_interpolated_string_node(node)
			highlight Tokens::PUNCTUATION, node.opening_loc
			highlight Tokens::PUNCTUATION, node.closing_loc
			super
		end

		def visit_symbol_node(node)
			highlight Tokens::SYMBOL, node.location
			super
		end

		def visit_block_node(node)
			if node.opening_loc.length == 1
				highlight Tokens::PUNCTUATION, node.opening_loc
			else
				highlight Tokens::KEYWORD, node.opening_loc
			end

			if node.closing_loc.length == 1
				highlight Tokens::PUNCTUATION, node.closing_loc
			else
				highlight Tokens::KEYWORD, node.closing_loc
			end

			super
		end

		def visit_case_node(node)
			highlight Tokens::KEYWORD, node.case_keyword_loc
			highlight Tokens::KEYWORD, node.end_keyword_loc
			super
		end

		def visit_case_match_node(node)
			highlight Tokens::KEYWORD, node.case_keyword_loc
			highlight Tokens::KEYWORD, node.end_keyword_loc
			super
		end

		def visit_module_node(node)
			highlight Tokens::KEYWORD, node.module_keyword_loc
			highlight Tokens::KEYWORD, node.end_keyword_loc
			super
		end

		def visit_if_node(node)
			highlight Tokens::KEYWORD, node.if_keyword_loc
			highlight Tokens::KEYWORD, node.end_keyword_loc

			if node.then_keyword&.length == 1
				highlight Tokens::OPERATOR, node.then_keyword_loc
			else
				highlight Tokens::KEYWORD, node.then_keyword_loc
			end

			super
		end

		def visit_when_node(node)
			highlight Tokens::KEYWORD, node.keyword_loc
			super
		end

		def visit_else_node(node)
			if node.else_keyword.length == 1
				highlight Tokens::OPERATOR, node.else_keyword_loc
			else
				highlight Tokens::KEYWORD, node.else_keyword_loc
			end

			super
		end

		def visit_block_argument_node(node)
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_and_node(node)
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_or_node(node)
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_local_variable_or_write_node(node)
			highlight Tokens::LOCAL_VARIABLE, node.name_loc
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_local_variable_and_write_node(node)
			highlight Tokens::LOCAL_VARIABLE, node.name_loc
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_rescue_node(node)
			highlight Tokens::KEYWORD, node.keyword_loc
			highlight Tokens::KEYWORD, node.operator_loc
			super
		end

		def visit_rest_parameter_node(node)
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_keyword_rest_parameter_node(node)
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_block_parameter_node(node)
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_while_node(node)
			highlight Tokens::KEYWORD, node.keyword_loc
			highlight Tokens::KEYWORD, node.closing_loc
			super
		end

		def visit_until_node(node)
			highlight Tokens::KEYWORD, node.keyword_loc
			highlight Tokens::KEYWORD, node.closing_loc
			super
		end

		def visit_next_node(node)
			highlight Tokens::KEYWORD, node.keyword_loc
			super
		end

		def visit_integer_node(node)
			highlight Tokens::INTEGER, node.location
			super
		end

		def visit_float_node(node)
			highlight Tokens::FLOAT, node.location
			super
		end

		def visit_hash_node(node)
			highlight Tokens::PUNCTUATION, node.opening_loc
			highlight Tokens::PUNCTUATION, node.closing_loc
			super
		end

		def visit_array_node(node)
			highlight Tokens::PUNCTUATION, node.opening_loc
			highlight Tokens::PUNCTUATION, node.closing_loc
			super
		end

		def visit_assoc_node(node)
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_forwarding_parameter_node(node)
			highlight Tokens::OPERATOR, node.location
			super
		end

		def visit_forwarding_super_node(node)
			highlight Tokens::KEYWORD, node.location
		end

		def visit_embedded_statements_node(node)
			highlight Tokens::PUNCTUATION, node.opening_loc
			highlight Tokens::PUNCTUATION, node.closing_loc
			super
		end

		def visit_parentheses_node(node)
			highlight Tokens::PUNCTUATION, node.opening_loc
			highlight Tokens::PUNCTUATION, node.closing_loc
			super
		end

		def visit_range_node(node)
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_in_node(node)
			highlight Tokens::KEYWORD, node.in_loc
			highlight Tokens::KEYWORD, node.then_loc
			super
		end

		def visit_array_pattern_node(node)
			highlight Tokens::PUNCTUATION, node.opening_loc
			highlight Tokens::PUNCTUATION, node.closing_loc
			super
		end

		def visit_alternation_pattern_node(node)
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_required_parameter_node(node)
			highlight Tokens::LOCAL_VARIABLE, node.location
			super
		end

		def visit_optional_parameter_node(node)
			highlight Tokens::LOCAL_VARIABLE, node.name_loc
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end

		def visit_capture_pattern_node(node)
			highlight Tokens::OPERATOR, node.operator_loc
			super
		end
	end
end
