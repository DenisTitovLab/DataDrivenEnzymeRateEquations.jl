#=
CODE FOR qssa RATE EQUATION DERIVATION
=#
using Distributed

@doc raw"""
    derive_general_qssa_rate_eq(metabs_and_regulators_kwargs...)

Derive a function that calculates the rate of a reaction using the Quasi Steady State Approximation (QSSA) given the list of substrates, products, and regulators.

The general QSSA rate equation is given by:

```math
Rate = \\frac{{V_{max}^a \\prod_{i=1}^{n} \\left(\\frac{S_i}{K_{a, i}}\\right) - V_{max}^a_{rev} \\prod_{i=1}^{n} \\left(\\frac{P_i}{K_{a, i}}\\right) \\cdot Z_{a, cat}^{n-1} \\cdot Z_{a, reg}^n + L \\left(V_{max}^i \\prod_{i=1}^{n} \\left(\\frac{S_i}{K_{i, i}}\\right) - V_{max}^i_{rev} \\prod_{i=1}^{n} \\left(\\frac{P_i}{K_{i, i}}\\right)\\right) \\cdot Z_{i, cat}^{n-1} \\cdot Z_{i, reg}^n}}{Z_{a, cat}^n \\cdot Z_{a, reg}^n + L \\cdot Z_{i, cat}^n \\cdot Z_{i, reg}^n}
```

where:
- ``V_{max}^a`` is the maximum rate of the forward reaction
- ``V_{max rev}^a`` is the maximum rate of the reverse reaction
- ``V_{max}^i`` is the maximum rate of the forward reaction
- ``V_{max rev}^i`` is the maximum rate of the reverse reaction
- ``S_i`` is the concentration of the ``i^{th}`` substrate
- ``P_i`` is the concentration of the ``i^{th}`` product
- ``K_{a, i}`` is the Michaelis constant for the ``i^{th}`` substrate
- ``K_{i, i}`` is the Michaelis constant for the ``i^{th}`` product
- ``Z`` is the allosteric factor for the catalytic site

# Arguments
- `metabs_and_regulators_kwargs...`: keyword arguments that specify the substrates, products, catalytic sites, regulatory sites, and other parameters of the reaction.

# Returns
- A function that calculates the rate of the reaction using the general qssa rate equation
- A tuple of the names of the metabolites and parameters used in the rate equation
"""
macro derive_general_qssa_rate_eq(metabs_and_regulators_kwargs)

    processed_input = getfield(__module__, Symbol(metabs_and_regulators_kwargs))
    expected_input_kwargs = [:substrates, :products, :regulators, :Keq, :rate_equation_name]
    if !haskey(processed_input, :regulators)
        processed_input.regulators = []
    end
    for kwarg in keys(processed_input)
        kwarg ∈ expected_input_kwargs || error(
            "invalid keyword: ",
            kwarg,
            ". The only supported keywords are: ",
            expected_input_kwargs,
        )
        @assert haskey(processed_input, kwarg) "missing keyword: $kwarg"
    end

    @assert 0 < length(processed_input.substrates) <= 3 "At least 1 and no more that 3 substrates are supported"
    @assert 0 < length(processed_input.products) <= 3 "At least 1 and no more that 3 products are supported"
    @assert 0 <= length(processed_input.regulators) <= 2 "no more that 2 regulators are supported"

    metab_names = generate_qssa_metab_names(processed_input)
    param_names = generate_qssa_param_names(processed_input)

    enz = NamedTuple()
    for (i, substrate) in enumerate(processed_input[:substrates])
        enz = merge(enz, (; Symbol(:S, i) => substrate))
    end
    for (i, product) in enumerate(processed_input[:products])
        enz = merge(enz, (; Symbol(:P, i) => product))
    end
    for (i, regulator) in enumerate(processed_input[:regulators])
        enz = merge(enz, (; Symbol(:R, i) => regulator))
    end

    #TODO: use Base.method_argnames(methods(general_qssa_rate_equation)[1])[2:end] to get args
    qssa_rate_eq_args = [:S1, :S2, :S3, :P1, :P2, :P3, :R1, :R2, :R3, :R4, :R5, :R6]
    missing_keys = filter(x -> !haskey(enz, x), qssa_rate_eq_args)
    for key in missing_keys
        enz = merge(enz, (; key => nothing))
    end
    # qualified_name = esc(GlobalRef(Main, :rate_equation))
    function_name = (
        hasproperty(processed_input, :rate_equation_name) ?
        esc(processed_input.rate_equation_name) : esc(:rate_equation)
    )
    return quote
        @inline function $(function_name)(metabs, params, Keq)
            general_qssa_rate_equation(
                $(enz.S1 isa Symbol) ? metabs.$(enz.S1) : 1.0,
                $(enz.S2 isa Symbol) ? metabs.$(enz.S2) : 1.0,
                $(enz.S3 isa Symbol) ? metabs.$(enz.S3) : 1.0,
                $(enz.P1 isa Symbol) ? metabs.$(enz.P1) : 1.0,
                $(enz.P2 isa Symbol) ? metabs.$(enz.P2) : 1.0,
                $(enz.P3 isa Symbol) ? metabs.$(enz.P3) : 1.0,
                params.Vmax,
                # $(enz.S1 isa Symbol && enz.S2 isa Symbol && enz.S3 isa Symbol) ?
                # params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.S3)) : 1.0,
                # $(enz.P1 isa Symbol && enz.P2 isa Symbol && enz.P3 isa Symbol) ?
                # params.$(Symbol("K_", enz.P1, "_", enz.P2, "_", enz.P3)) : 1.0,
                params.$(Symbol(
                    "K",
                    (enz.S1 isa Symbol) ? Symbol("_", enz.S1) : "",
                    (enz.S2 isa Symbol) ? Symbol("_", enz.S2) : "",
                    (enz.S3 isa Symbol) ? Symbol("_", enz.S3) : "",
                )),
                params.$(Symbol(
                    "K",
                    (enz.P1 isa Symbol) ? Symbol("_", enz.P1) : "",
                    (enz.P2 isa Symbol) ? Symbol("_", enz.P2) : "",
                    (enz.P3 isa Symbol) ? Symbol("_", enz.P3) : "",
                )),
                #Z
                calculate_qssa_z(
                    $(enz.S1 isa Symbol) ? metabs.$(enz.S1) : 0.0,
                    $(enz.S2 isa Symbol) ? metabs.$(enz.S2) : 0.0,
                    $(enz.S3 isa Symbol) ? metabs.$(enz.S3) : 0.0,
                    $(enz.P1 isa Symbol) ? metabs.$(enz.P1) : 0.0,
                    $(enz.P2 isa Symbol) ? metabs.$(enz.P2) : 0.0,
                    $(enz.P3 isa Symbol) ? metabs.$(enz.P3) : 0.0,
                    $(enz.R1 isa Symbol) ? metabs.$(enz.R1) : 0.0,
                    $(enz.R2 isa Symbol) ? metabs.$(enz.R2) : 0.0,
                    $(enz.S1 isa Symbol) ? params.$(Symbol("K_", enz.S1)) : Inf,
                    $(enz.S2 isa Symbol) ? params.$(Symbol("K_", enz.S2)) : Inf,
                    $(enz.S3 isa Symbol) ? params.$(Symbol("K_", enz.S3)) : Inf,
                    $(enz.P1 isa Symbol) ? params.$(Symbol("K_", enz.P1)) : Inf,
                    $(enz.P2 isa Symbol) ? params.$(Symbol("K_", enz.P2)) : Inf,
                    $(enz.P3 isa Symbol) ? params.$(Symbol("K_", enz.P3)) : Inf,
                    $(enz.R1 isa Symbol) ? params.$(Symbol("K_", enz.R1)) : Inf,
                    $(enz.R2 isa Symbol) ? params.$(Symbol("K_", enz.R2)) : Inf,
                    $(enz.S1 isa Symbol && enz.S2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2)) : Inf,
                    $(enz.S1 isa Symbol && enz.S3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3)) : Inf,
                    $(enz.S1 isa Symbol && enz.P1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P1)) : Inf,
                    $(enz.S1 isa Symbol && enz.P2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P2)) : Inf,
                    $(enz.S1 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P3)) : Inf,
                    $(enz.S1 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.R1)) : Inf,
                    $(enz.S1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.R2)) : Inf,
                    $(enz.S2 isa Symbol && enz.S3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3)) : Inf,
                    $(enz.S2 isa Symbol && enz.P1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P1)) : Inf,
                    $(enz.S2 isa Symbol && enz.P2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P2)) : Inf,
                    $(enz.S2 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P3)) : Inf,
                    $(enz.S2 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.R1)) : Inf,
                    $(enz.S2 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.R2)) : Inf,
                    $(enz.S3 isa Symbol && enz.P1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P1)) : Inf,
                    $(enz.S3 isa Symbol && enz.P2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P2)) : Inf,
                    $(enz.S3 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P3)) : Inf,
                    $(enz.S3 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.R1)) : Inf,
                    $(enz.S3 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.R2)) : Inf,
                    $(enz.P1 isa Symbol && enz.P2 isa Symbol) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.P2)) : Inf,
                    $(enz.P1 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.P3)) : Inf,
                    $(enz.P1 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.R1)) : Inf,
                    $(enz.P1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.R2)) : Inf,
                    $(enz.P2 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.P2, "_", enz.P3)) : Inf,
                    $(enz.P2 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.P2, "_", enz.R1)) : Inf,
                    $(enz.P2 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.P2, "_", enz.R2)) : Inf,
                    $(enz.P3 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.P3, "_", enz.R1)) : Inf,
                    $(enz.P3 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.P3, "_", enz.R2)) : Inf,
                    $(enz.R1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.R1, "_", enz.R2)) : Inf,
                    $(enz.S1 isa Symbol && enz.S2 isa Symbol && enz.S3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.S3)) : Inf,
                    $(enz.S1 isa Symbol && enz.S2 isa Symbol && enz.P1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P1)) : Inf,
                    $(enz.S1 isa Symbol && enz.S2 isa Symbol && enz.P2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P2)) : Inf,
                    $(enz.S1 isa Symbol && enz.S2 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P3)) : Inf,
                    $(enz.S1 isa Symbol && enz.S2 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.R1)) : Inf,
                    $(enz.S1 isa Symbol && enz.S2 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.R2)) : Inf,
                    $(enz.S1 isa Symbol && enz.S3 isa Symbol && enz.P1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P1)) : Inf,
                    $(enz.S1 isa Symbol && enz.S3 isa Symbol && enz.P2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P2)) : Inf,
                    $(enz.S1 isa Symbol && enz.S3 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P3)) : Inf,
                    $(enz.S1 isa Symbol && enz.S3 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.R1)) : Inf,
                    $(enz.S1 isa Symbol && enz.S3 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.R2)) : Inf,
                    $(enz.S1 isa Symbol && enz.P1 isa Symbol && enz.P2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P1, "_", enz.P2)) : Inf,
                    $(enz.S1 isa Symbol && enz.P1 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P1, "_", enz.P3)) : Inf,
                    $(enz.S1 isa Symbol && enz.P1 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P1, "_", enz.R1)) : Inf,
                    $(enz.S1 isa Symbol && enz.P1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P1, "_", enz.R2)) : Inf,
                    $(enz.S1 isa Symbol && enz.P2 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P2, "_", enz.P3)) : Inf,
                    $(enz.S1 isa Symbol && enz.P2 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P2, "_", enz.R1)) : Inf,
                    $(enz.S1 isa Symbol && enz.P2 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P2, "_", enz.R2)) : Inf,
                    $(enz.S1 isa Symbol && enz.P3 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P3, "_", enz.R1)) : Inf,
                    $(enz.S1 isa Symbol && enz.P3 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P3, "_", enz.R2)) : Inf,
                    $(enz.S1 isa Symbol && enz.R1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.R1, "_", enz.R2)) : Inf,
                    $(enz.S2 isa Symbol && enz.S3 isa Symbol && enz.P1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P1)) : Inf,
                    $(enz.S2 isa Symbol && enz.S3 isa Symbol && enz.P2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P2)) : Inf,
                    $(enz.S2 isa Symbol && enz.S3 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P3)) : Inf,
                    $(enz.S2 isa Symbol && enz.S3 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.R1)) : Inf,
                    $(enz.S2 isa Symbol && enz.S3 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.R2)) : Inf,
                    $(enz.S2 isa Symbol && enz.P1 isa Symbol && enz.P2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P1, "_", enz.P2)) : Inf,
                    $(enz.S2 isa Symbol && enz.P1 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P1, "_", enz.P3)) : Inf,
                    $(enz.S2 isa Symbol && enz.P1 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P1, "_", enz.R1)) : Inf,
                    $(enz.S2 isa Symbol && enz.P1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P1, "_", enz.R2)) : Inf,
                    $(enz.S2 isa Symbol && enz.P2 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P2, "_", enz.P3)) : Inf,
                    $(enz.S2 isa Symbol && enz.P2 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P2, "_", enz.R1)) : Inf,
                    $(enz.S2 isa Symbol && enz.P2 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P2, "_", enz.R2)) : Inf,
                    $(enz.S2 isa Symbol && enz.P3 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P3, "_", enz.R1)) : Inf,
                    $(enz.S2 isa Symbol && enz.P3 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P3, "_", enz.R2)) : Inf,
                    $(enz.S2 isa Symbol && enz.R1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.R1, "_", enz.R2)) : Inf,
                    $(enz.S3 isa Symbol && enz.P1 isa Symbol && enz.P2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P1, "_", enz.P2)) : Inf,
                    $(enz.S3 isa Symbol && enz.P1 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P1, "_", enz.P3)) : Inf,
                    $(enz.S3 isa Symbol && enz.P1 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P1, "_", enz.R1)) : Inf,
                    $(enz.S3 isa Symbol && enz.P1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P1, "_", enz.R2)) : Inf,
                    $(enz.S3 isa Symbol && enz.P2 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P2, "_", enz.P3)) : Inf,
                    $(enz.S3 isa Symbol && enz.P2 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P2, "_", enz.R1)) : Inf,
                    $(enz.S3 isa Symbol && enz.P2 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P2, "_", enz.R2)) : Inf,
                    $(enz.S3 isa Symbol && enz.P3 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P3, "_", enz.R1)) : Inf,
                    $(enz.S3 isa Symbol && enz.P3 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P3, "_", enz.R2)) : Inf,
                    $(enz.S3 isa Symbol && enz.R1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.R1, "_", enz.R2)) : Inf,
                    $(enz.P1 isa Symbol && enz.P2 isa Symbol && enz.P3 isa Symbol) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.P2, "_", enz.P3)) : Inf,
                    $(enz.P1 isa Symbol && enz.P2 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.P2, "_", enz.R1)) : Inf,
                    $(enz.P1 isa Symbol && enz.P2 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.P2, "_", enz.R2)) : Inf,
                    $(enz.P1 isa Symbol && enz.P3 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.P3, "_", enz.R1)) : Inf,
                    $(enz.P1 isa Symbol && enz.P3 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.P3, "_", enz.R2)) : Inf,
                    $(enz.P1 isa Symbol && enz.R1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.R1, "_", enz.R2)) : Inf,
                    $(enz.P2 isa Symbol && enz.P3 isa Symbol && enz.R1 isa Symbol) ?
                    params.$(Symbol("K_", enz.P2, "_", enz.P3, "_", enz.R1)) : Inf,
                    $(enz.P2 isa Symbol && enz.P3 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.P2, "_", enz.P3, "_", enz.R2)) : Inf,
                    $(enz.P2 isa Symbol && enz.R1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.P2, "_", enz.R1, "_", enz.R2)) : Inf,
                    $(enz.P3 isa Symbol && enz.R1 isa Symbol && enz.R2 isa Symbol) ?
                    params.$(Symbol("K_", enz.P3, "_", enz.R1, "_", enz.R2)) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.S3, "_", enz.P1)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.S3, "_", enz.P2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.S3, "_", enz.P3)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.S3, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.S3, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P1, "_", enz.P2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P1, "_", enz.P3)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P1, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P2, "_", enz.P3)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P2, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P2, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P3, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.P3, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S2, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P1, "_", enz.P2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P1, "_", enz.P3)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P1, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P2, "_", enz.P3)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P2, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P2, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P3, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.P3, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.S3, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P1, "_", enz.P2, "_", enz.P3)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P1, "_", enz.P2, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P1, "_", enz.P2, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P1, "_", enz.P3, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P1, "_", enz.P3, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P1, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P2, "_", enz.P3, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P2, "_", enz.P3, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P2, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S1, "_", enz.P3, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P1, "_", enz.P2)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P1, "_", enz.P3)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P1, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P2, "_", enz.P3)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P2, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P2, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P3, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.P3, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.S3, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P1, "_", enz.P2, "_", enz.P3)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P1, "_", enz.P2, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P1, "_", enz.P2, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P1, "_", enz.P3, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P1, "_", enz.P3, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P1, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P2, "_", enz.P3, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P2, "_", enz.P3, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P2, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S2, "_", enz.P3, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P1, "_", enz.P2, "_", enz.P3)) :
                    Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P1, "_", enz.P2, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P1, "_", enz.P2, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P1, "_", enz.P3, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P1, "_", enz.P3, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P1, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P2, "_", enz.P3, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P2, "_", enz.P3, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P2, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.S3, "_", enz.P3, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.P2, "_", enz.P3, "_", enz.R1)) :
                    Inf,
                    $(
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.P2, "_", enz.P3, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.P2, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.P1, "_", enz.P3, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol("K_", enz.P2, "_", enz.P3, "_", enz.R1, "_", enz.R2)) :
                    Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                    $(
                        enz.S1 isa Symbol &&
                        enz.S2 isa Symbol &&
                        enz.S3 isa Symbol &&
                        enz.P1 isa Symbol &&
                        enz.P2 isa Symbol &&
                        enz.P3 isa Symbol &&
                        enz.R1 isa Symbol &&
                        enz.R2 isa Symbol
                    ) ?
                    params.$(Symbol(
                        "K_",
                        enz.S1,
                        "_",
                        enz.S2,
                        "_",
                        enz.S3,
                        "_",
                        enz.P1,
                        "_",
                        enz.P2,
                        "_",
                        enz.P3,
                        "_",
                        enz.R1,
                        "_",
                        enz.R2,
                    )) : Inf,
                ),
                Keq,
            )
        end

        metab_names = $(esc(metab_names))
        param_names = $(esc(param_names))

        metab_names, param_names
    end
end

@inline function general_qssa_rate_equation(
    S1,
    S2,
    S3,
    P1,
    P2,
    P3,
    Vmax,
    K_S1_S2_S3,
    K_P1_P2_P3,
    Z,
    Keq,
)
    Vmax = 1.0
    Vmax_rev = Vmax * K_P1_P2_P3 / (Keq * K_S1_S2_S3)
    Rate = (Vmax * (S1 * S2 * S3 / K_S1_S2_S3) - Vmax_rev * (P1 * P2 * P3 / K_P1_P2_P3)) / Z
    return Rate
end

@inline function calculate_qssa_z(
    S1,
    S2,
    S3,
    P1,
    P2,
    P3,
    R1,
    R2,
    K_S1,
    K_S2,
    K_S3,
    K_P1,
    K_P2,
    K_P3,
    K_R1,
    K_R2,
    K_S1_S2,
    K_S1_S3,
    K_S1_P1,
    K_S1_P2,
    K_S1_P3,
    K_S1_R1,
    K_S1_R2,
    K_S2_S3,
    K_S2_P1,
    K_S2_P2,
    K_S2_P3,
    K_S2_R1,
    K_S2_R2,
    K_S3_P1,
    K_S3_P2,
    K_S3_P3,
    K_S3_R1,
    K_S3_R2,
    K_P1_P2,
    K_P1_P3,
    K_P1_R1,
    K_P1_R2,
    K_P2_P3,
    K_P2_R1,
    K_P2_R2,
    K_P3_R1,
    K_P3_R2,
    K_R1_R2,
    K_S1_S2_S3,
    K_S1_S2_P1,
    K_S1_S2_P2,
    K_S1_S2_P3,
    K_S1_S2_R1,
    K_S1_S2_R2,
    K_S1_S3_P1,
    K_S1_S3_P2,
    K_S1_S3_P3,
    K_S1_S3_R1,
    K_S1_S3_R2,
    K_S1_P1_P2,
    K_S1_P1_P3,
    K_S1_P1_R1,
    K_S1_P1_R2,
    K_S1_P2_P3,
    K_S1_P2_R1,
    K_S1_P2_R2,
    K_S1_P3_R1,
    K_S1_P3_R2,
    K_S1_R1_R2,
    K_S2_S3_P1,
    K_S2_S3_P2,
    K_S2_S3_P3,
    K_S2_S3_R1,
    K_S2_S3_R2,
    K_S2_P1_P2,
    K_S2_P1_P3,
    K_S2_P1_R1,
    K_S2_P1_R2,
    K_S2_P2_P3,
    K_S2_P2_R1,
    K_S2_P2_R2,
    K_S2_P3_R1,
    K_S2_P3_R2,
    K_S2_R1_R2,
    K_S3_P1_P2,
    K_S3_P1_P3,
    K_S3_P1_R1,
    K_S3_P1_R2,
    K_S3_P2_P3,
    K_S3_P2_R1,
    K_S3_P2_R2,
    K_S3_P3_R1,
    K_S3_P3_R2,
    K_S3_R1_R2,
    K_P1_P2_P3,
    K_P1_P2_R1,
    K_P1_P2_R2,
    K_P1_P3_R1,
    K_P1_P3_R2,
    K_P1_R1_R2,
    K_P2_P3_R1,
    K_P2_P3_R2,
    K_P2_R1_R2,
    K_P3_R1_R2,
    K_S1_S2_S3_P1,
    K_S1_S2_S3_P2,
    K_S1_S2_S3_P3,
    K_S1_S2_S3_R1,
    K_S1_S2_S3_R2,
    K_S1_S2_P1_P2,
    K_S1_S2_P1_P3,
    K_S1_S2_P1_R1,
    K_S1_S2_P1_R2,
    K_S1_S2_P2_P3,
    K_S1_S2_P2_R1,
    K_S1_S2_P2_R2,
    K_S1_S2_P3_R1,
    K_S1_S2_P3_R2,
    K_S1_S2_R1_R2,
    K_S1_S3_P1_P2,
    K_S1_S3_P1_P3,
    K_S1_S3_P1_R1,
    K_S1_S3_P1_R2,
    K_S1_S3_P2_P3,
    K_S1_S3_P2_R1,
    K_S1_S3_P2_R2,
    K_S1_S3_P3_R1,
    K_S1_S3_P3_R2,
    K_S1_S3_R1_R2,
    K_S1_P1_P2_P3,
    K_S1_P1_P2_R1,
    K_S1_P1_P2_R2,
    K_S1_P1_P3_R1,
    K_S1_P1_P3_R2,
    K_S1_P1_R1_R2,
    K_S1_P2_P3_R1,
    K_S1_P2_P3_R2,
    K_S1_P2_R1_R2,
    K_S1_P3_R1_R2,
    K_S2_S3_P1_P2,
    K_S2_S3_P1_P3,
    K_S2_S3_P1_R1,
    K_S2_S3_P1_R2,
    K_S2_S3_P2_P3,
    K_S2_S3_P2_R1,
    K_S2_S3_P2_R2,
    K_S2_S3_P3_R1,
    K_S2_S3_P3_R2,
    K_S2_S3_R1_R2,
    K_S2_P1_P2_P3,
    K_S2_P1_P2_R1,
    K_S2_P1_P2_R2,
    K_S2_P1_P3_R1,
    K_S2_P1_P3_R2,
    K_S2_P1_R1_R2,
    K_S2_P2_P3_R1,
    K_S2_P2_P3_R2,
    K_S2_P2_R1_R2,
    K_S2_P3_R1_R2,
    K_S3_P1_P2_P3,
    K_S3_P1_P2_R1,
    K_S3_P1_P2_R2,
    K_S3_P1_P3_R1,
    K_S3_P1_P3_R2,
    K_S3_P1_R1_R2,
    K_S3_P2_P3_R1,
    K_S3_P2_P3_R2,
    K_S3_P2_R1_R2,
    K_S3_P3_R1_R2,
    K_P1_P2_P3_R1,
    K_P1_P2_P3_R2,
    K_P1_P2_R1_R2,
    K_P1_P3_R1_R2,
    K_P2_P3_R1_R2,
    K_S1_S2_S3_P1_P2,
    K_S1_S2_S3_P1_P3,
    K_S1_S2_S3_P1_R1,
    K_S1_S2_S3_P1_R2,
    K_S1_S2_S3_P2_P3,
    K_S1_S2_S3_P2_R1,
    K_S1_S2_S3_P2_R2,
    K_S1_S2_S3_P3_R1,
    K_S1_S2_S3_P3_R2,
    K_S1_S2_S3_R1_R2,
    K_S1_S2_P1_P2_P3,
    K_S1_S2_P1_P2_R1,
    K_S1_S2_P1_P2_R2,
    K_S1_S2_P1_P3_R1,
    K_S1_S2_P1_P3_R2,
    K_S1_S2_P1_R1_R2,
    K_S1_S2_P2_P3_R1,
    K_S1_S2_P2_P3_R2,
    K_S1_S2_P2_R1_R2,
    K_S1_S2_P3_R1_R2,
    K_S1_S3_P1_P2_P3,
    K_S1_S3_P1_P2_R1,
    K_S1_S3_P1_P2_R2,
    K_S1_S3_P1_P3_R1,
    K_S1_S3_P1_P3_R2,
    K_S1_S3_P1_R1_R2,
    K_S1_S3_P2_P3_R1,
    K_S1_S3_P2_P3_R2,
    K_S1_S3_P2_R1_R2,
    K_S1_S3_P3_R1_R2,
    K_S1_P1_P2_P3_R1,
    K_S1_P1_P2_P3_R2,
    K_S1_P1_P2_R1_R2,
    K_S1_P1_P3_R1_R2,
    K_S1_P2_P3_R1_R2,
    K_S2_S3_P1_P2_P3,
    K_S2_S3_P1_P2_R1,
    K_S2_S3_P1_P2_R2,
    K_S2_S3_P1_P3_R1,
    K_S2_S3_P1_P3_R2,
    K_S2_S3_P1_R1_R2,
    K_S2_S3_P2_P3_R1,
    K_S2_S3_P2_P3_R2,
    K_S2_S3_P2_R1_R2,
    K_S2_S3_P3_R1_R2,
    K_S2_P1_P2_P3_R1,
    K_S2_P1_P2_P3_R2,
    K_S2_P1_P2_R1_R2,
    K_S2_P1_P3_R1_R2,
    K_S2_P2_P3_R1_R2,
    K_S3_P1_P2_P3_R1,
    K_S3_P1_P2_P3_R2,
    K_S3_P1_P2_R1_R2,
    K_S3_P1_P3_R1_R2,
    K_S3_P2_P3_R1_R2,
    K_P1_P2_P3_R1_R2,
    K_S1_S2_S3_P1_P2_P3,
    K_S1_S2_S3_P1_P2_R1,
    K_S1_S2_S3_P1_P2_R2,
    K_S1_S2_S3_P1_P3_R1,
    K_S1_S2_S3_P1_P3_R2,
    K_S1_S2_S3_P1_R1_R2,
    K_S1_S2_S3_P2_P3_R1,
    K_S1_S2_S3_P2_P3_R2,
    K_S1_S2_S3_P2_R1_R2,
    K_S1_S2_S3_P3_R1_R2,
    K_S1_S2_P1_P2_P3_R1,
    K_S1_S2_P1_P2_P3_R2,
    K_S1_S2_P1_P2_R1_R2,
    K_S1_S2_P1_P3_R1_R2,
    K_S1_S2_P2_P3_R1_R2,
    K_S1_S3_P1_P2_P3_R1,
    K_S1_S3_P1_P2_P3_R2,
    K_S1_S3_P1_P2_R1_R2,
    K_S1_S3_P1_P3_R1_R2,
    K_S1_S3_P2_P3_R1_R2,
    K_S1_P1_P2_P3_R1_R2,
    K_S2_S3_P1_P2_P3_R1,
    K_S2_S3_P1_P2_P3_R2,
    K_S2_S3_P1_P2_R1_R2,
    K_S2_S3_P1_P3_R1_R2,
    K_S2_S3_P2_P3_R1_R2,
    K_S2_P1_P2_P3_R1_R2,
    K_S3_P1_P2_P3_R1_R2,
    K_S1_S2_S3_P1_P2_P3_R1,
    K_S1_S2_S3_P1_P2_P3_R2,
    K_S1_S2_S3_P1_P2_R1_R2,
    K_S1_S2_S3_P1_P3_R1_R2,
    K_S1_S2_S3_P2_P3_R1_R2,
    K_S1_S2_P1_P2_P3_R1_R2,
    K_S1_S3_P1_P2_P3_R1_R2,
    K_S2_S3_P1_P2_P3_R1_R2,
    K_S1_S2_S3_P1_P2_P3_R1_R2,
)
    one_metab_bound = (
        S1 / K_S1 +
        S2 / K_S2 +
        S3 / K_S3 +
        P1 / K_P1 +
        P2 / K_P2 +
        P3 / K_P3 +
        R1 / K_R1 +
        R2 / K_R2
    )
    two_metab_bound =
        S1 * (
            (S2 / K_S1_S2) +
            (S3 / K_S1_S3) +
            (P1 / K_S1_P1) +
            (P2 / K_S1_P2) +
            (P3 / K_S1_P3) +
            (R1 / K_S1_R1) +
            (R2 / K_S1_R2)
        ) +
        S2 * (
            (S3 / K_S2_S3) +
            (P1 / K_S2_P1) +
            (P2 / K_S2_P2) +
            (P3 / K_S2_P3) +
            (R1 / K_S2_R1) +
            (R2 / K_S2_R2)
        ) +
        S3 * (
            (P1 / K_S3_P1) +
            (P2 / K_S3_P2) +
            (P3 / K_S3_P3) +
            (R1 / K_S3_R1) +
            (R2 / K_S3_R2)
        ) +
        P1 * ((P2 / K_P1_P2) + (P3 / K_P1_P3) + (R1 / K_P1_R1) + (R2 / K_P1_R2)) +
        P2 * ((P3 / K_P2_P3) + (R1 / K_P2_R1) + (R2 / K_P2_R2)) +
        P3 * ((R1 / K_P3_R1) + (R2 / K_P3_R2)) +
        (R1 * R2 / K_R1_R2)

    three_metab_bound =
        S1 * (
            S2 * (
                (S3 / K_S1_S2_S3) +
                (P1 / K_S1_S2_P1) +
                (P2 / K_S1_S2_P2) +
                (P3 / K_S1_S2_P3) +
                (R1 / K_S1_S2_R1) +
                (R2 / K_S1_S2_R2)
            ) +
            S3 * (
                (P1 / K_S1_S3_P1) +
                (P2 / K_S1_S3_P2) +
                (P3 / K_S1_S3_P3) +
                (R1 / K_S1_S3_R1) +
                (R2 / K_S1_S3_R2)
            ) +
            P1 * (
                (P2 / K_S1_P1_P2) +
                (P3 / K_S1_P1_P3) +
                (R1 / K_S1_P1_R1) +
                (R2 / K_S1_P1_R2)
            ) +
            P2 * ((P3 / K_S1_P2_P3) + (R1 / K_S1_P2_R1) + (R2 / K_S1_P2_R2)) +
            P3 * ((R1 / K_S1_P3_R1) + (R2 / K_S1_P3_R2)) +
            (R1 * R2 / K_S1_R1_R2)
        ) +
        S2 * (
            S3 * (
                (P1 / K_S2_S3_P1) +
                (P2 / K_S2_S3_P2) +
                (P3 / K_S2_S3_P3) +
                (R1 / K_S2_S3_R1) +
                (R2 / K_S2_S3_R2)
            ) +
            P1 * (
                (P2 / K_S2_P1_P2) +
                (P3 / K_S2_P1_P3) +
                (R1 / K_S2_P1_R1) +
                (R2 / K_S2_P1_R2)
            ) +
            P2 * ((P3 / K_S2_P2_P3) + (R1 / K_S2_P2_R1) + (R2 / K_S2_P2_R2)) +
            P3 * ((R1 / K_S2_P3_R1) + (R2 / K_S2_P3_R2)) +
            (R1 * R2 / K_S2_R1_R2)
        ) +
        S3 * (
            P1 * (
                (P2 / K_S3_P1_P2) +
                (P3 / K_S3_P1_P3) +
                (R1 / K_S3_P1_R1) +
                (R2 / K_S3_P1_R2)
            ) +
            P2 * ((P3 / K_S3_P2_P3) + (R1 / K_S3_P2_R1) + (R2 / K_S3_P2_R2)) +
            P3 * ((R1 / K_S3_P3_R1) + (R2 / K_S3_P3_R2)) +
            (R1 * R2 / K_S3_R1_R2)
        ) +
        P1 * (
            P2 * ((P3 / K_P1_P2_P3) + (R1 / K_P1_P2_R1) + (R2 / K_P1_P2_R2)) +
            P3 * ((R1 / K_P1_P3_R1) + (R2 / K_P1_P3_R2)) +
            (R1 * R2 / K_P1_R1_R2)
        ) +
        P2 * (P3 * ((R1 / K_P2_P3_R1) + (R2 / K_P2_P3_R2)) + (R1 * R2 / K_P2_R1_R2)) +
        P3 * (R1 * R2 / K_P3_R1_R2)

    four_metab_bound =
        S1 * (
            S2 * (
                S3 * (
                    (P1 / K_S1_S2_S3_P1) +
                    (P2 / K_S1_S2_S3_P2) +
                    (P3 / K_S1_S2_S3_P3) +
                    (R1 / K_S1_S2_S3_R1) +
                    (R2 / K_S1_S2_S3_R2)
                ) +
                P1 * (
                    (P2 / K_S1_S2_P1_P2) +
                    (P3 / K_S1_S2_P1_P3) +
                    (R1 / K_S1_S2_P1_R1) +
                    (R2 / K_S1_S2_P1_R2)
                ) +
                P2 * ((P3 / K_S1_S2_P2_P3) + (R1 / K_S1_S2_P2_R1) + (R2 / K_S1_S2_P2_R2)) +
                P3 * ((R1 / K_S1_S2_P3_R1) + (R2 / K_S1_S2_P3_R2)) +
                (R1 * R2 / K_S1_S2_R1_R2)
            ) +
            S3 * (
                P1 * (
                    (P2 / K_S1_S3_P1_P2) +
                    (P3 / K_S1_S3_P1_P3) +
                    (R1 / K_S1_S3_P1_R1) +
                    (R2 / K_S1_S3_P1_R2)
                ) +
                P2 * ((P3 / K_S1_S3_P2_P3) + (R1 / K_S1_S3_P2_R1) + (R2 / K_S1_S3_P2_R2)) +
                P3 * ((R1 / K_S1_S3_P3_R1) + (R2 / K_S1_S3_P3_R2)) +
                (R1 * R2 / K_S1_S3_R1_R2)
            ) +
            P1 * (
                P2 * ((P3 / K_S1_P1_P2_P3) + (R1 / K_S1_P1_P2_R1) + (R2 / K_S1_P1_P2_R2)) +
                P3 * ((R1 / K_S1_P1_P3_R1) + (R2 / K_S1_P1_P3_R2)) +
                (R1 * R2 / K_S1_P1_R1_R2)
            ) +
            P2 * (
                P3 * ((R1 / K_S1_P2_P3_R1) + (R2 / K_S1_P2_P3_R2)) +
                (R1 * R2 / K_S1_P2_R1_R2)
            ) +
            P3 * (R1 * R2 / K_S1_P3_R1_R2)
        ) +
        S2 * (
            S3 * (
                P1 * (
                    (P2 / K_S2_S3_P1_P2) +
                    (P3 / K_S2_S3_P1_P3) +
                    (R1 / K_S2_S3_P1_R1) +
                    (R2 / K_S2_S3_P1_R2)
                ) +
                P2 * ((P3 / K_S2_S3_P2_P3) + (R1 / K_S2_S3_P2_R1) + (R2 / K_S2_S3_P2_R2)) +
                P3 * ((R1 / K_S2_S3_P3_R1) + (R2 / K_S2_S3_P3_R2)) +
                (R1 * R2 / K_S2_S3_R1_R2)
            ) +
            P1 * (
                P2 * ((P3 / K_S2_P1_P2_P3) + (R1 / K_S2_P1_P2_R1) + (R2 / K_S2_P1_P2_R2)) +
                P3 * ((R1 / K_S2_P1_P3_R1) + (R2 / K_S2_P1_P3_R2)) +
                (R1 * R2 / K_S2_P1_R1_R2)
            ) +
            P2 * (
                P3 * ((R1 / K_S2_P2_P3_R1) + (R2 / K_S2_P2_P3_R2)) +
                (R1 * R2 / K_S2_P2_R1_R2)
            ) +
            P3 * (R1 * R2 / K_S2_P3_R1_R2)
        ) +
        S3 * (
            P1 * (
                P2 * ((P3 / K_S3_P1_P2_P3) + (R1 / K_S3_P1_P2_R1) + (R2 / K_S3_P1_P2_R2)) +
                P3 * ((R1 / K_S3_P1_P3_R1) + (R2 / K_S3_P1_P3_R2)) +
                (R1 * R2 / K_S3_P1_R1_R2)
            ) +
            P2 * (
                P3 * ((R1 / K_S3_P2_P3_R1) + (R2 / K_S3_P2_P3_R2)) +
                (R1 * R2 / K_S3_P2_R1_R2)
            ) +
            P3 * (R1 * R2 / K_S3_P3_R1_R2)
        ) +
        P1 * (
            P2 * (
                P3 * ((R1 / K_P1_P2_P3_R1) + (R2 / K_P1_P2_P3_R2)) +
                (R1 * R2 / K_P1_P2_R1_R2)
            ) + P3 * (R1 * R2 / K_P1_P3_R1_R2)
        ) +
        P2 * (P3 * (R1 * R2 / K_P2_P3_R1_R2))


    five_metab_bound = (
        S1 * (
            S2 * (
                S3 * (
                    P1 * (
                        (P2 / K_S1_S2_S3_P1_P2) +
                        (P3 / K_S1_S2_S3_P1_P3) +
                        (R1 / K_S1_S2_S3_P1_R1) +
                        (R2 / K_S1_S2_S3_P1_R2)
                    ) +
                    P2 * (
                        (P3 / K_S1_S2_S3_P2_P3) +
                        (R1 / K_S1_S2_S3_P2_R1) +
                        (R2 / K_S1_S2_S3_P2_R2)
                    ) +
                    P3 * ((R1 / K_S1_S2_S3_P3_R1) + (R2 / K_S1_S2_S3_P3_R2)) +
                    (R1 * R2 / K_S1_S2_S3_R1_R2)
                ) +
                P1 * (
                    P2 * (
                        (P3 / K_S1_S2_P1_P2_P3) +
                        (R1 / K_S1_S2_P1_P2_R1) +
                        (R2 / K_S1_S2_P1_P2_R2)
                    ) +
                    P3 * ((R1 / K_S1_S2_P1_P3_R1) + (R2 / K_S1_S2_P1_P3_R2)) +
                    (R1 * R2 / K_S1_S2_P1_R1_R2)
                ) +
                P2 * (
                    P3 * ((R1 / K_S1_S2_P2_P3_R1) + (R2 / K_S1_S2_P2_P3_R2)) +
                    (R1 * R2 / K_S1_S2_P2_R1_R2)
                ) +
                P3 * (R1 * R2 / K_S1_S2_P3_R1_R2)
            ) +
            S3 * (
                P1 * (
                    P2 * (
                        (P3 / K_S1_S3_P1_P2_P3) +
                        (R1 / K_S1_S3_P1_P2_R1) +
                        (R2 / K_S1_S3_P1_P2_R2)
                    ) +
                    P3 * ((R1 / K_S1_S3_P1_P3_R1) + (R2 / K_S1_S3_P1_P3_R2)) +
                    (R1 * R2 / K_S1_S3_P1_R1_R2)
                ) +
                P2 * (
                    P3 * ((R1 / K_S1_S3_P2_P3_R1) + (R2 / K_S1_S3_P2_P3_R2)) +
                    (R1 * R2 / K_S1_S3_P2_R1_R2)
                ) +
                P3 * (R1 * R2 / K_S1_S3_P3_R1_R2)
            ) +
            P1 * (
                P2 * (
                    P3 * ((R1 / K_S1_P1_P2_P3_R1) + (R2 / K_S1_P1_P2_P3_R2)) +
                    (R1 * R2 / K_S1_P1_P2_R1_R2)
                ) + P3 * (R1 * R2 / K_S1_P1_P3_R1_R2)
            ) +
            P2 * (P3 * (R1 * R2 / K_S1_P2_P3_R1_R2))
        ) +
        S2 * (
            S3 * (
                P1 * (
                    P2 * (
                        (P3 / K_S2_S3_P1_P2_P3) +
                        (R1 / K_S2_S3_P1_P2_R1) +
                        (R2 / K_S2_S3_P1_P2_R2)
                    ) +
                    P3 * ((R1 / K_S2_S3_P1_P3_R1) + (R2 / K_S2_S3_P1_P3_R2)) +
                    (R1 * R2 / K_S2_S3_P1_R1_R2)
                ) +
                P2 * (
                    P3 * ((R1 / K_S2_S3_P2_P3_R1) + (R2 / K_S2_S3_P2_P3_R2)) +
                    (R1 * R2 / K_S2_S3_P2_R1_R2)
                ) +
                P3 * (R1 * R2 / K_S2_S3_P3_R1_R2)
            ) +
            P1 * (
                P2 * (
                    P3 * ((R1 / K_S2_P1_P2_P3_R1) + (R2 / K_S2_P1_P2_P3_R2)) +
                    (R1 * R2 / K_S2_P1_P2_R1_R2)
                ) + P3 * (R1 * R2 / K_S2_P1_P3_R1_R2)
            ) +
            P2 * (P3 * (R1 * R2 / K_S2_P2_P3_R1_R2))
        ) +
        S3 * (
            P1 * (
                P2 * (
                    P3 * ((R1 / K_S3_P1_P2_P3_R1) + (R2 / K_S3_P1_P2_P3_R2)) +
                    (R1 * R2 / K_S3_P1_P2_R1_R2)
                ) + P3 * (R1 * R2 / K_S3_P1_P3_R1_R2)
            ) + P2 * (P3 * (R1 * R2 / K_S3_P2_P3_R1_R2))
        ) +
        P1 * (P2 * (P3 * (R1 * R2 / K_P1_P2_P3_R1_R2)))
    )

    six_metab_bound = (
        S1 * (
            S2 * (
                S3 * (
                    P1 * (
                        P2 * (
                            (P3 / K_S1_S2_S3_P1_P2_P3) +
                            (R1 / K_S1_S2_S3_P1_P2_R1) +
                            (R2 / K_S1_S2_S3_P1_P2_R2)
                        ) +
                        P3 * ((R1 / K_S1_S2_S3_P1_P3_R1) + (R2 / K_S1_S2_S3_P1_P3_R2)) +
                        (R1 * R2 / K_S1_S2_S3_P1_R1_R2)
                    ) +
                    P2 * (
                        P3 * ((R1 / K_S1_S2_S3_P2_P3_R1) + (R2 / K_S1_S2_S3_P2_P3_R2)) +
                        (R1 * R2 / K_S1_S2_S3_P2_R1_R2)
                    ) +
                    P3 * (R1 * R2 / K_S1_S2_S3_P3_R1_R2)
                ) +
                P1 * (
                    (P2 * P3 * R1 / K_S1_S2_P1_P2_P3_R1) +
                    (P2 * P3 * R2 / K_S1_S2_P1_P2_P3_R2) +
                    (P2 * R1 * R2 / K_S1_S2_P1_P2_R1_R2) +
                    (P3 * R1 * R2 / K_S1_S2_P1_P3_R1_R2)
                ) +
                (P2 * P3 * R1 * R2 / K_S1_S2_P2_P3_R1_R2)
            ) +
            S3 * (
                P1 * (
                    P2 * (
                        P3 * ((R1 / K_S1_S3_P1_P2_P3_R1) + (R2 / K_S1_S3_P1_P2_P3_R2)) +
                        (R1 * R2 / K_S1_S3_P1_P2_R1_R2)
                    ) + (P3 * R1 * R2 / K_S1_S3_P1_P3_R1_R2)
                ) + (P2 * P3 * R1 * R2 / K_S1_S3_P2_P3_R1_R2)
            ) +
            (P1 * P2 * P3 * R1 * R2 / K_S1_P1_P2_P3_R1_R2)
        ) +
        S2 * (
            S3 * (
                P1 * (
                    P2 * (
                        (P3 * R1 / K_S2_S3_P1_P2_P3_R1) +
                        (P3 * R2 / K_S2_S3_P1_P2_P3_R2) +
                        (R1 * R2 / K_S2_S3_P1_P2_R1_R2)
                    ) + (P3 * R1 * R2 / K_S2_S3_P1_P3_R1_R2)
                ) + (P2 * P3 * R1 * R2 / K_S2_S3_P2_P3_R1_R2)
            ) + (P1 * P2 * P3 * R1 * R2 / K_S2_P1_P2_P3_R1_R2)
        ) +
        (S3 * P1 * P2 * P3 * R1 * R2 / K_S3_P1_P2_P3_R1_R2)
    )

    seven_metab_bound = (
        (S1 * S2 * S3 * P1 * P2 * P3 * R1 / K_S1_S2_S3_P1_P2_P3_R1) +
        (S1 * S2 * S3 * P1 * P2 * P3 * R2 / K_S1_S2_S3_P1_P2_P3_R2) +
        (S1 * S2 * S3 * P1 * P2 * R1 * R2 / K_S1_S2_S3_P1_P2_R1_R2) +
        (S1 * S2 * S3 * P1 * P3 * R1 * R2 / K_S1_S2_S3_P1_P3_R1_R2) +
        (S1 * S2 * S3 * P2 * P3 * R1 * R2 / K_S1_S2_S3_P2_P3_R1_R2) +
        (S1 * S2 * P1 * P2 * P3 * R1 * R2 / K_S1_S2_P1_P2_P3_R1_R2) +
        (S1 * S3 * P1 * P2 * P3 * R1 * R2 / K_S1_S3_P1_P2_P3_R1_R2) +
        (S2 * S3 * P1 * P2 * P3 * R1 * R2 / K_S2_S3_P1_P2_P3_R1_R2)
    )

    eight_metab_bound = (S1 * S2 * S3 * P1 * P2 * P3 * R1 * R2 / K_S1_S2_S3_P1_P2_P3_R1_R2)

    return 1 +
           one_metab_bound +
           two_metab_bound +
           three_metab_bound +
           four_metab_bound +
           five_metab_bound +
           six_metab_bound +
           seven_metab_bound +
           eight_metab_bound
end

"Generate the names of the parameters for the rate equation using the same input as @derive_general_qssa_rate_eq"
function generate_qssa_param_names(processed_input)
    metab_names = ()
    for field in keys(processed_input)
        if field ∈ [:substrates, :products, :regulators]
            metab_names = (metab_names..., processed_input[field]...)
        end
    end
    param_names = (:Vmax,)
    for metab in metab_names
        param_names = (param_names..., Symbol("K_", metab))
    end
    for (i, metab1) in enumerate(metab_names[1:(end-1)])
        for metab2 in metab_names[(i+1):end]
            param_names = (param_names..., Symbol("K_", metab1, "_", metab2))
            for metab3 in metab_names[(i+2):end]
                param_names =
                    (param_names..., Symbol("K_", metab1, "_", metab2, "_", metab3))
                for metab4 in metab_names[(i+3):end]
                    param_names = (
                        param_names...,
                        Symbol("K_", metab1, "_", metab2, "_", metab3, "_", metab4),
                    )
                    for metab5 in metab_names[(i+4):end]
                        param_names = (
                            param_names...,
                            Symbol(
                                "K_",
                                metab1,
                                "_",
                                metab2,
                                "_",
                                metab3,
                                "_",
                                metab4,
                                "_",
                                metab5,
                            ),
                        )
                        for metab6 in metab_names[(i+5):end]
                            param_names = (
                                param_names...,
                                Symbol(
                                    "K_",
                                    metab1,
                                    "_",
                                    metab2,
                                    "_",
                                    metab3,
                                    "_",
                                    metab4,
                                    "_",
                                    metab5,
                                    "_",
                                    metab6,
                                ),
                            )
                            for metab7 in metab_names[(i+6):end]
                                param_names = (
                                    param_names...,
                                    Symbol(
                                        "K_",
                                        metab1,
                                        "_",
                                        metab2,
                                        "_",
                                        metab3,
                                        "_",
                                        metab4,
                                        "_",
                                        metab5,
                                        "_",
                                        metab6,
                                        "_",
                                        metab7,
                                    ),
                                )
                                for metab8 in metab_names[(i+7):end]
                                    param_names = (
                                        param_names...,
                                        Symbol(
                                            "K_",
                                            metab1,
                                            "_",
                                            metab2,
                                            "_",
                                            metab3,
                                            "_",
                                            metab4,
                                            "_",
                                            metab5,
                                            "_",
                                            metab6,
                                            "_",
                                            metab7,
                                            "_",
                                            metab8,
                                        ),
                                    )
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return param_names
end

"Generate the names of the metabolites for the rate equation using the same input as @derive_general_qssa_rate_eq"
function generate_qssa_metab_names(processed_input)
    metab_names = ()
    for field in keys(processed_input)
        if field ∈ [:substrates, :products, :regulators]
            metab_names = (metab_names..., processed_input[field]...)
        end
    end
    return Tuple(unique(metab_names))
end
