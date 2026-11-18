# frozen_string_literal: true

# Matches syntax nodes that are plain literals: they have no side effects and mean the same thing
# wherever they are evaluated, so their source can be moved and run when a method is defined.
module Empirical::LiteralNode
	extend self

	def ===(node)
		case node
		in Prism::IntegerNode | Prism::FloatNode | Prism::RationalNode | Prism::ImaginaryNode
			true
		in Prism::SymbolNode | Prism::NilNode | Prism::TrueNode | Prism::FalseNode | Prism::RegularExpressionNode
			true
		in Prism::StringNode
			!node.heredoc?
		in Prism::ArrayNode
			node.elements.all? { |element| self === element }
		in Prism::HashNode
			node.elements.all? { |element| Prism::AssocNode === element && self === element.key && self === element.value }
		in Prism::RangeNode
			(node.left.nil? || self === node.left) && (node.right.nil? || self === node.right)
		else
			false
		end
	end
end
