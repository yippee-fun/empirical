# frozen_string_literal: true

module Empirical
	class PositionalParamsType
		def initialize(types: [], rest: nil)
			@types = types
			@rest_type = rest
		end

		def ===(value)
			types = @types

			i, len = 0, types.length
			while i < len
				return false unless types[i] === value[i]
				i += 1
			end

			if (rest_type = @rest_type)
				rest = value.drop(@types.size)
				return false unless rest_type === rest
			else
				return false if value.size > len
			end

			true
		end
	end

	class KeywordParamsType
		def initialize(types: {}, rest: nil)
			@types = types
			@rest_type = rest
		end

		def ===(value)
			types = @types

			types.each do |key, type|
				return false unless type === value[key]
			end

			if (rest_type = @rest_type)
				rest = value.drop(types.size).to_h
				return false unless rest_type === rest
			else
				return false if value.size > types.size
			end

			true
		end
	end
end
