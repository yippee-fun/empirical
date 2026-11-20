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

	private def fun?(node)
		node.name == :fun && node.receiver.nil? && (node.arguments || node.block)
	end

	# The `fun` call a call defines, when it has the block: itself, or the one it wraps.
	# In `private fun foo => Type do ... end`, Ruby attaches the block to `private`, not to `fun`.
	private def fun_defined_by(node)
		return node if fun?(node)

		wrapped_fun(node)&.first
	end

	private def wrapped_fun(outer)
		wrappers = [outer]
		current = outer

		loop do
			case current.arguments&.arguments
			in [Prism::CallNode => current]
				return [current, wrappers] if fun?(current)
				return if current.block
				wrappers << current
			else
				return
			end
		end
	end

	# False for `fun self.name` and `fun object.name`, which define singleton methods.
	private def instance_method_fun?(fun)
		case fun.arguments&.arguments
		in [Prism::KeywordHashNode[elements: [Prism::AssocNode[key: Prism::CallNode[receiver: Prism::Node]]]]]
			false
		else
			true
		end
	end

	# Finds the ivars a class body declares with `var name: Type` or Literal’s `prop :name, Type`,
	# as [ivar, type node, stored type name].
	private def declarations_in(body)
		statements = (Prism::StatementsNode === body) ? body.body : []

		statements.flat_map do |statement|
			case statement
			in Prism::CallNode[
				name: :var,
				receiver: nil,
				arguments: Prism::ArgumentsNode[arguments: [Prism::KeywordHashNode[elements:]]]
			]
				elements.filter_map do |element|
					declaration(element.key, element.value) if element in Prism::AssocNode[key: Prism::SymbolNode]
				end
			in Prism::CallNode[
				name: :prop,
				receiver: nil,
				arguments: Prism::ArgumentsNode[arguments: [Prism::SymbolNode => name, type, *]]
			]
				[declaration(name, type)]
			else
				[]
			end
		end
	end

	private def declaration(name, type)
		[:"@#{name.unescaped}", type, "T_#{site}_#{type.location.start_offset}"]
	end

	# Identifies this file in the names of stored types, so the same source always generates the same code.
	private def site
		@site ||= Digest::SHA256.hexdigest(@path || @source)[0, 12]
	end
end
