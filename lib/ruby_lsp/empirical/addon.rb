# frozen_string_literal: true

require "ruby_lsp/addon"

module RubyLsp
	module Empirical
		class Addon < ::RubyLsp::Addon
			def activate(global_state, message_queue)
			end

			def deactivate
			end

			def name
				"Empirical"
			end

			def version
				"0.1.0"
			end
		end

		class IndexingEnhancement < RubyIndexer::Enhancement
			def on_call_node_enter(node)
				call_name = node.name
				owner = @listener.current_owner
				location = node.location

				return unless owner
				return unless :fun == call_name
				return unless node.arguments

				# Match the pattern: fun foo(...) => ReturnType do ... end
				case node
				in {
					arguments: Prism::ArgumentsNode[
						arguments: [
							Prism::KeywordHashNode[
								elements: [
									Prism::AssocNode[
										key: signature,
										value: _return_type
									]
								]
							]
						]
					],
					block: Prism::BlockNode
				}
					# Extract method name from signature
					method_name = case signature
					in Prism::LocalVariableReadNode
						signature.name.to_s
					in Prism::ConstantReadNode
						signature.name.to_s
					in Prism::CallNode
						signature.name.to_s
					else
						return
					end

					# Extract parameters from signature if it's a call node
					parameters = []
					if signature.is_a?(Prism::CallNode) && signature.arguments
						signature.arguments.arguments.each do |arg|
							case arg
							in Prism::KeywordHashNode
								arg.elements.each do |element|
									case element
									in Prism::AssocNode[key: Prism::SymbolNode => key, value: Prism::ArrayNode[elements: [_]] => value] if value.opening == "["
										parameters << RubyIndexer::Entry::RestParameter.new(name: key.unescaped.to_sym)
									in Prism::AssocNode[key: Prism::SymbolNode => key]
										parameters << RubyIndexer::Entry::OptionalKeywordParameter.new(name: key.unescaped.delete_suffix("?").to_sym)
									else
										nil
									end
								end
							else
								nil
							end
						end
					end

					@listener.add_method(
						method_name,
						location,
						[RubyIndexer::Entry::Signature.new(parameters)]
					)
				end
			end
		end
	end
end
