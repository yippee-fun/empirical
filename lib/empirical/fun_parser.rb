# frozen_string_literal: true

class Empirical::FunParser
	USAGE = "Expected `fun name(parameters) => ReturnType do ... end`."
	METHOD_NAME = /\A(?:[A-Za-z_]|[^[:ascii:]])(?:[A-Za-z0-9_]|[^[:ascii:]])*[?!]?\z/
	LOCAL_NAME = /\A(?:[a-z_]|[^[:ascii:]])(?:[A-Za-z0-9_]|[^[:ascii:]])*\z/

	def initialize(path:)
		@path = path
	end

	#: (Prism::CallNode, body: Prism::BlockNode?, wrappers: Array[Prism::CallNode]) -> Empirical::Fun
	def parse(call, body:, wrappers:)
		signature, return_type = split(call)

		fail!(call, "A `fun` needs a `do ... end` body.") unless body
		fail!(body, "The body of a `fun` must be a `do ... end` block, not braces.") unless body.opening == "do"

		if call.opening_loc || wrappers.any?(&:opening_loc)
			fail!(call, "Don’t wrap a `fun` definition in parentheses.")
		end

		arguments = case signature
		in Prism::LocalVariableReadNode | Prism::ConstantReadNode
			[]
		in Prism::CallNode[name:, block: nil | Prism::BlockArgumentNode] if METHOD_NAME.match?(name)
			signature.arguments&.arguments || []
		else
			fail!(signature, "#{USAGE} Setters and operators can’t be defined with `fun`; use `def` for those.")
		end

		parameters = arguments.flat_map { |argument| parameters_from(argument) }
		parameters << untyped(signature.block) if Prism::CallNode === signature && signature.block

		ensure_single_splat(parameters, signature)

		Empirical::Fun.new(
			call:,
			signature:,
			body:,
			parameters: with_defaults(parameters, body),
			return_type: return_type_from(return_type),
		)
	end

	private def split(call)
		case call.arguments&.arguments
		in [Prism::KeywordHashNode[elements: [Prism::AssocNode[key:, value:, operator_loc: Prism::Location]]]]
			[key, value]
		else
			fail!(call, "#{USAGE} Setters and operators can’t be defined with `fun`; use `def` for those.")
		end
	end

	private def parameters_from(argument)
		case argument
		in Prism::LocalVariableWriteNode
			fail!(argument, "A `fun` can’t take positional parameters. Use a keyword parameter, `#{argument.name}: Type`, or `def`.")
		in Prism::KeywordHashNode
			parameters = argument.elements.map { |element| keyword_from(element) }
			ensure_splat_first(parameters)
			parameters
		in Prism::SplatNode | Prism::ForwardingArgumentsNode
			untyped(argument)
		else
			fail!(argument, "Invalid parameter `#{argument.slice}`. Use `name: Type`.")
		end
	end

	private def ensure_splat_first(parameters)
		parameters.drop(1).each do |parameter|
			fail!(parameter.node, "A positional splat must come before keyword parameters.") if parameter.kind == :positional_splat
		end
	end

	private def keyword_from(element)
		case element
		in Prism::AssocSplatNode
			untyped(element)
		in Prism::AssocNode[key: Prism::SymbolNode[opening_loc: nil] => key, value:]
			name = key.unescaped
			optional = name.end_with?("?")
			name = name.delete_suffix("?").to_sym

			case value
			in Prism::ArrayNode[elements: [Prism::SplatNode]] if value.opening == "["
				fail!(element, "`[*Type]` is reserved. Use `#{name}: [Type]` to type each element of a splat.")
			in Prism::ArrayNode[elements: [type]] if value.opening == "["
				fail!(element, "A positional splat can’t be optional.") if optional
				ensure_local_name(name, element)
				parameter(:positional_splat, name, element, value, "::Literal::Types._Array(#{single_line(type)})")
			in Prism::HashNode[elements: [Prism::AssocSplatNode]]
				fail!(element, "`{**Type}` is reserved. Use `#{name}: {KeyType => ValueType}` to type a keyword splat.")
			in Prism::HashNode[elements: [Prism::AssocNode[key: key_type, value: value_type]]]
				fail!(element, "A keyword splat can’t be optional.") if optional
				ensure_local_name(name, element)
				parameter(:keyword_splat, name, element, value, "::Literal::Types._Hash(#{single_line(key_type)}, #{single_line(value_type)})")
			else
				type_source = optional ? "::Literal::Types._Nilable(#{single_line(value)})" : single_line(value)
				parameter(:keyword, name, element, value, type_source, optional:)
			end
		else
			fail!(element, "Invalid keyword parameter `#{element.slice}`. Use `name: Type`.")
		end
	end

	# A keyword can be named anything a label can, but a splat has to be a valid local variable.
	private def ensure_local_name(name, node)
		unless LOCAL_NAME.match?(name) && !Empirical::FunGenerator::RESERVED_WORDS.include?(name)
			fail!(node, "`#{name}` can’t be the name of a splat.")
		end
	end

	private def parameter(kind, name, node, type, type_source, optional: false)
		Empirical::Fun::Parameter.new(kind:, name:, node:, type:, type_source:, default: nil, default_line: nil, optional:)
	end

	private def untyped(node)
		Empirical::Fun::Parameter.new(kind: :untyped, name: nil, node:, type: nil, type_source: nil, default: nil, default_line: nil, optional: false)
	end

	private def ensure_single_splat(parameters, signature)
		positional = parameters.count { it.kind == :positional_splat || Prism::SplatNode === it.node }
		keyword = parameters.count { it.kind == :keyword_splat || Prism::AssocSplatNode === it.node }

		fail!(signature, "A method can only take one positional splat.") if positional > 1
		fail!(signature, "A method can only take one keyword splat.") if keyword > 1
	end

	private def with_defaults(parameters, body)
		defaults = defaults_from(body)

		parameters = parameters.map do |parameter|
			if parameter.kind == :keyword && (default = defaults.delete(parameter.name))
				parameter.with(default: single_line(default), default_line: default.location.start_line)
			else
				parameter
			end
		end

		defaults.each do |name, node|
			fail!(node, "The default for `#{name}` doesn’t match a keyword parameter in the signature.")
		end

		parameters
	end

	# Defaults are given as keyword block parameters, e.g. `do |name: "World"|`.
	private def defaults_from(body)
		case body.parameters
		in nil | Prism::BlockParametersNode[parameters: nil, locals: []]
			{}
		in Prism::BlockParametersNode[
			parameters: Prism::ParametersNode[
				requireds: [], optionals: [], rest: nil, posts: [], keywords:, keyword_rest: nil, block: nil
			],
			locals: []
		]
			keywords.to_h do |keyword|
				case keyword
				in Prism::OptionalKeywordParameterNode[name:, value:]
					[name, value]
				else
					fail!(keyword, "Block parameters of a `fun` are for defaults and must have a value, e.g. `|#{keyword.name}: value|`.")
				end
			end
		in Prism::BlockParametersNode => parameters
			fail!(parameters, "Block parameters of a `fun` are for defaults and must all be keywords, e.g. `|name: value|`.")
		else
			fail!(body, "You can’t use `it` or numbered parameters in the body of a `fun`.")
		end
	end

	private def return_type_from(node)
		kind = case node
		in Prism::LocalVariableReadNode[name: :void] | Prism::CallNode[name: :void, receiver: nil, arguments: nil, block: nil]
			:void
		in Prism::LocalVariableReadNode[name: :never] | Prism::CallNode[name: :never, receiver: nil, arguments: nil, block: nil]
			:never
		in Prism::LocalVariableReadNode[name: :itself] | Prism::CallNode[name: :itself, receiver: nil, arguments: nil, block: nil]
			:itself
		else
			:typed
		end

		Empirical::Fun::ReturnType.new(kind:, node:, source: single_line(node))
	end

	# Types and defaults are moved to another line, so they have to fit on one to keep line numbers intact.
	private def single_line(node)
		source = node.slice
		return source unless source.include?("\n")

		result = "".b
		position = 0

		Prism.lex(source).value.each do |token, _|
			location = token.location
			text = source.byteslice(location.start_offset, location.length)

			result.append_as_bytes(source.byteslice(position, location.start_offset - position).tr("\n", " "))
			position = location.end_offset

			case token.type
			in :COMMENT
				# dropped
			in :NEWLINE | :IGNORED_NEWLINE
				result.append_as_bytes(" ")
			else
				fail!(node, "A type or default that spans lines can’t contain a multi-line string or heredoc.") if text.include?("\n")
				result.append_as_bytes(text)
			end
		end

		result.force_encoding(source.encoding)
	end

	def fail!(node, message)
		raise Empirical::TypedSignatureError, "#{@path || '(eval)'}:#{node.location.start_line}: #{message}"
	end
end
