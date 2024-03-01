var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = DataDrivenEnzymeRateEqs","category":"page"},{"location":"#DataDrivenEnzymeRateEqs","page":"Home","title":"DataDrivenEnzymeRateEqs","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for DataDrivenEnzymeRateEqs.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [DataDrivenEnzymeRateEqs]","category":"page"},{"location":"#DataDrivenEnzymeRateEqs.calculate_all_parameter_removal_codes-Tuple{Tuple{Symbol, Vararg{Symbol}}}","page":"Home","title":"DataDrivenEnzymeRateEqs.calculate_all_parameter_removal_codes","text":"Generate all possibles codes for ways that mirror params for a and i states of MWC enzyme can be removed from the rate equation\n\n\n\n\n\n","category":"method"},{"location":"#DataDrivenEnzymeRateEqs.data_driven_rate_equation_selection-Tuple{Function, DataFrames.DataFrame, Tuple{Symbol, Vararg{Symbol}}, Tuple{Symbol, Vararg{Symbol}}, Tuple{Int64, Int64}, Bool}","page":"Home","title":"DataDrivenEnzymeRateEqs.data_driven_rate_equation_selection","text":"data_driven_rate_equation_selection(\n    general_rate_equation::Function,\n    data::DataFrame,\n    metab_names::Tuple{Symbol,Vararg{Symbol}},\n    param_names::Tuple{Symbol,Vararg{Symbol}},\n    range_number_params::Tuple{Int,Int},\n    forward_model_selection::Bool,\n)\n\nThis function is used to perform data-driven rate equation selection using a general rate equation and data. The function will select the best rate equation by iteratively removing parameters from the general rate equation and finding an equation that yield best test scores on data not used for fitting.\n\nArguments\n\ngeneral_rate_equation::Function: Function that takes a NamedTuple of metabolite concentrations (with metab_names keys) and parameters (with param_names keys) and returns an enzyme rate.\ndata::DataFrame: DataFrame containing the data with column Rate and columns for each metab_names where each row is one measurement. It also needs to have a column source that contains a string that identifies the source of the data. This is used to calculate the weights for each figure in the publication.\nmetab_names::Tuple: Tuple of metabolite names that correspond to the metabolites of rate_equation and column names in data.\nparam_names::Tuple: Tuple of parameter names that correspond to the parameters of rate_equation.\nrange_number_params::Tuple{Int,Int}: A tuple of integers representing the range of the number of parameters of generalrateequation to search over.\nforward_model_selection::Bool: A boolean indicating whether to use forward model selection (true) or reverse model selection (false).\n\nReturns nothing, but saves a csv file for each num_params with the results of the training for each combination of parameters tested and a csv file with test results for top 10% of the best results with each number of parameters tested.\n\n\n\n\n\n","category":"method"},{"location":"#DataDrivenEnzymeRateEqs.fit_rate_equation-Tuple{Function, DataFrames.DataFrame, Tuple, Tuple}","page":"Home","title":"DataDrivenEnzymeRateEqs.fit_rate_equation","text":"fit_rate_equation(\n    rate_equation::Function,\n    data::DataFrame,\n    metab_names::Tuple,\n    param_names::Tuple;\n    n_iter = 20\n\n)\n\nFit rate_equation to data and return loss and best fit parameters.\n\nArguments\n\nrate_equation::Function: Function that takes a NamedTuple of metabolite concentrations (with metab_names keys) and parameters (with param_names keys) and returns an enzyme rate.\ndata::DataFrame: DataFrame containing the data with column Rate and columns for each metab_names where each row is one measurement. It also needs to have a column source that contains a string that identifies the source of the data. This is used to calculate the weights for each figure in the publication.\nmetab_names::Tuple: Tuple of metabolite names that correspond to the metabolites of rate_equation and column names in data.\nparam_names::Tuple: Tuple of parameter names that correspond to the parameters of rate_equation.\nn_iter::Int: Number of iterations to run the fitting process.\n\nReturns\n\nloss::Float64: Loss of the best fit.\nparams::NamedTuple: Best fit parameters with param_names keys\n\nExample\n\nusing DataFrames\ndata = DataFrame(\n    Rate = [1.0, 2.0, 3.0],\n    A = [1.0, 2.0, 3.0],\n    source = [\"Figure 1\", \"Figure 1\", \"Figure 2\"]\n)\nrate_equation(metabs, params) = params.Vmax * metabs.S / (1 + metabs.S / params.K_S)\nfit_rate_equation(rate_equation, data, (:A,), (:Vmax, :K_S))\n\n\n\n\n\n","category":"method"},{"location":"#DataDrivenEnzymeRateEqs.forward_selection_next_param_removal_codes-NTuple{5, Any}","page":"Home","title":"DataDrivenEnzymeRateEqs.forward_selection_next_param_removal_codes","text":"Calculate nt_param_removal_codes with num_params including non-zero term combinations for codes (excluding alpha terms) in each previous_param_removal_codes that has num_params-1\n\n\n\n\n\n","category":"method"},{"location":"#DataDrivenEnzymeRateEqs.generate_metab_names-Tuple{Any}","page":"Home","title":"DataDrivenEnzymeRateEqs.generate_metab_names","text":"Generate the names of the metabolites for the rate equation using the same input as @derivegeneralmwcrateeq\n\n\n\n\n\n","category":"method"},{"location":"#DataDrivenEnzymeRateEqs.generate_param_names-Tuple{Any}","page":"Home","title":"DataDrivenEnzymeRateEqs.generate_param_names","text":"Generate the names of the parameters for the rate equation using the same input as @derivegeneralmwcrateeq\n\n\n\n\n\n","category":"method"},{"location":"#DataDrivenEnzymeRateEqs.loss_rate_equation-Tuple{Any, Function, NamedTuple, Any, Vector{Vector{Int64}}}","page":"Home","title":"DataDrivenEnzymeRateEqs.loss_rate_equation","text":"Loss function used for fitting that calculate log of ratio of rate equation predicting of rate and rate data\n\n\n\n\n\n","category":"method"},{"location":"#DataDrivenEnzymeRateEqs.param_rescaling-Tuple{Any, Any}","page":"Home","title":"DataDrivenEnzymeRateEqs.param_rescaling","text":"Rescaling of fitting parameters from [0, 10] scale that optimizer uses to actual values\n\n\n\n\n\n","category":"method"},{"location":"#DataDrivenEnzymeRateEqs.param_subset_select-Tuple{Any, Any, Any}","page":"Home","title":"DataDrivenEnzymeRateEqs.param_subset_select","text":"Function to convert parameter vector to vector where some params are equal to 0, Inf or each other based on ntparamremoval_code\n\n\n\n\n\n","category":"method"},{"location":"#DataDrivenEnzymeRateEqs.reverse_selection_next_param_removal_codes-NTuple{5, Any}","page":"Home","title":"DataDrivenEnzymeRateEqs.reverse_selection_next_param_removal_codes","text":"Calculate param_removal_codes with num_params including zero term combinations for codes (excluding alpha terms) in each previous_param_removal_codes that has num_params+1\n\n\n\n\n\n","category":"method"},{"location":"#DataDrivenEnzymeRateEqs.test_rate_equation-Tuple{Function, Any, NamedTuple, Tuple{Symbol, Vararg{Symbol}}, Tuple{Symbol, Vararg{Symbol}}}","page":"Home","title":"DataDrivenEnzymeRateEqs.test_rate_equation","text":"Function to calculate loss for a given rate_equation and nt_fitted_params on data that was not used for training\n\n\n\n\n\n","category":"method"},{"location":"#DataDrivenEnzymeRateEqs.@derive_general_mwc_rate_eq-Tuple","page":"Home","title":"DataDrivenEnzymeRateEqs.@derive_general_mwc_rate_eq","text":"derive_general_mwc_rate_eq(metabs_and_regulators_kwargs...)\n\nDerive a function that calculates the rate of a reaction using the general MWC rate equation given the list of substrates, products, and regulators that bind to specific cat or reg sites.\n\nThe general MWC rate equation is given by:\n\nRate = fracV_max^a prod_i=1^n left(fracS_iK_a iright) - V_max^a_rev prod_i=1^n left(fracP_iK_a iright) cdot Z_a cat^n-1 cdot Z_a reg^n + L left(V_max^i prod_i=1^n left(fracS_iK_i iright) - V_max^i_rev prod_i=1^n left(fracP_iK_i iright)right) cdot Z_i cat^n-1 cdot Z_i reg^nZ_a cat^n cdot Z_a reg^n + L cdot Z_i cat^n cdot Z_i reg^n\n\nwhere:\n\nV_max^a is the maximum rate of the forward reaction\nV_max^a_rev is the maximum rate of the reverse reaction\nV_max^i is the maximum rate of the forward reaction\nV_max^i_rev is the maximum rate of the reverse reaction\nS_i is the concentration of the i^th substrate\nP_i is the concentration of the i^th product\nK_a i is the Michaelis constant for the i^th substrate\nK_i i is the Michaelis constant for the i^th product\nZ_a cat is the allosteric factor for the catalytic site\nZ_i cat is the allosteric factor for the catalytic site\nZ_a reg is the allosteric factor for the regulatory site\nZ_i reg is the allosteric factor for the regulatory site\nL is the concentration of the ligand\nn is the oligomeric state of the enzyme\n\nArguments\n\nmetabs_and_regulators_kwargs...: keyword arguments that specify the substrates, products, catalytic sites, regulatory sites, and other parameters of the reaction.\n\nReturns\n\nA function that calculates the rate of the reaction using the general MWC rate equation\nA tuple of the names of the metabolites and parameters used in the rate equation\n\n\n\n\n\n","category":"macro"}]
}
