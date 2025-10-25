# frozen_string_literal: true

# TODO:
# for attr_reader, using keyword "name: type" hash syntax instead of hash rockets clashes
# against empirical return type syntax , ge attr_reader bob: String, looks
# like it takes a String argument say... much better if constrained to
# attr_reader bob => String ?
# For accessors and writers they both take and return the same type so I guess either
# syntax could work...
class Empirical::AttrProcessor < Empirical::BaseProcessor
	ATTR_METHODS = Set[:attr_accessor, :attr_reader, :attr_writer].freeze

	def visit_call_node(node)
		if ATTR_METHODS.include?(node.name)
			visit_attr_call_node(node)
		end

		super
	end

	def visit_attr_call_node(node)
		# TODO: improve errors, as per `fun`
		raise SyntaxError unless node.arguments
		raise SyntaxError if node.receiver

		# First argument will be the hash of names/types
		argument = node.arguments.arguments.first
		return unless argument

		typed_attrs = case argument
			in Prism::HashNode[elements: elements]
				extract_typed_attrs_from_hash(elements)
			in Prism::KeywordHashNode[elements: elements]
				extract_typed_attrs_from_hash(elements)
			else
				# Not typed
				return
		end

		# TODO: If no typed attributes found, raise syntax error?
		raise SyntaxError if typed_attrs.empty?

		# TODO: join seems wrong here, we are producing diffenernt whitespace that original source?
		stripped_args = typed_attrs.map { ":#{it[:name]}" }.join(", ")

		# Strip types from attr_*
		@annotations << [
			node.arguments.location.start_offset,
			node.arguments.location.end_offset - node.arguments.location.start_offset,
			" #{stripped_args}",
			]

		post_end_buffer = []

		typed_attrs.each do |attr|
			attr_name = attr[:name]
			attr_type_slice = attr[:type]
			attr_type_ident = unique_type_ident(attr_type_slice)

			post_end_buffer << store_type(attr_type_slice, as: attr_type_ident)

			# TODO: here we check on read for attr_readre and on write for writer/accessor, makes sense?
			case node.name
			when :attr_reader
				post_end_buffer << typed_getter(attr_name, attr_type_ident)
			when :attr_writer, :attr_accessor
				post_end_buffer << typed_setter(attr_name, attr_type_ident)
			end
		end

		# Insert methods after the attr_* call
		if post_end_buffer.any?
			@annotations << [
				node.location.end_offset,
				0,
				";#{post_end_buffer.join(';')};",
				]
		end
	end

	private

	def extract_typed_attrs_from_hash(elements)
		elements.reduce([]) do |types, assoc|
			case assoc
			in Prism::AssocNode[key: Prism::SymbolNode => key, value: type]
				types << {
					name: key.unescaped,
					type: type.slice,
				}
			else
			end
		end
	end

	# TODO: readability!
	def typed_getter(attr_name, type_ident)
		"alias_method(:__original_#{attr_name}, :#{attr_name});def #{attr_name};__value = __original_#{attr_name};raise(::Empirical::TypeError.attr_type_error(name: '#{attr_name}', value: __value, expected: ::Empirical::TypeStore::#{type_ident}, attr_type: 'reader', context: self)) unless ::Empirical::TypeStore::#{type_ident} === __value;__value;end"
	end

	def typed_setter(attr_name, type_ident)
		"alias_method(:__original_#{attr_name}=, :#{attr_name}=);def #{attr_name}=(value);raise(::Empirical::TypeError.attr_type_error(name: '#{attr_name}', value: value, expected: ::Empirical::TypeStore::#{type_ident}, attr_type: 'writer', context: self)) unless ::Empirical::TypeStore::#{type_ident} === value;send(:__original_#{attr_name}=, value);end"
	end

	# TODO: duplication
	#
	def unique_type_ident(type)
		"T__#{type.tr('()', '_').gsub(/[^a-zA-Z0-9_]/, '')}__#{SecureRandom.alphanumeric(32)}"
	end

	def store_type(type, as:)
		"::Empirical::TypeStore::#{as} = #{type}"
	end
end
