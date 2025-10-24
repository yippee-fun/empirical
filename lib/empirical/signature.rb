class Empirical::Signature < Literal::Data
	prop :method_ident, Symbol
	prop :positional_params_type, Empirical::PositionalParamsType
	prop :keyword_params_type, Empirical::KeywordParamsType
end