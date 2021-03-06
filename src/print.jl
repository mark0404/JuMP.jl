#  Copyright 2017, Iain Dunning, Joey Huchette, Miles Lubin, and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.
#############################################################################
# JuMP
# An algebraic modeling language for Julia
# See http://github.com/JuliaOpt/JuMP.jl
#############################################################################
# print.jl
# All "pretty printers" for JuMP types.
# - Delegates to appropriate handler methods for REPL or IJulia.
# - These handler methods then pass the correct symbols to use into a
#   generic string builder. The IJulia handlers will also wrap in MathJax
#   start/close tags.
# - To find printing code for a type in this file, search for `## TypeName`
# - Code here does not need to be fast, in fact simplicity trumps speed
#   within reason as this code is thorny enough as it is.
# - Corresponding tests are in test/print.jl, although test/operator.jl
#   is also testing the constraint/expression code extensively as well.
# - Base.print and Base.string both delegate to Base.show, if they are not
#   separately defined.
#############################################################################

# Used for dispatching
abstract type PrintMode end
abstract type REPLMode <: PrintMode end
abstract type IJuliaMode <: PrintMode end

# Whether something is zero or not for the purposes of printing it
# oneunit is useful e.g. if coef is a Unitful quantity.
is_zero_for_printing(coef) = abs(coef) < 1e-10 * oneunit(coef)
# Whether something is one or not for the purposes of printing it.
is_one_for_printing(coef) = is_zero_for_printing(abs(coef) - oneunit(coef))
sign_string(coef) = coef < zero(coef) ? " - " : " + "

# Helper function that rounds carefully for the purposes of printing
# e.g.   5.3  =>  5.3
#        1.0  =>  1
function string_round(f::Float64)
    iszero(f) && return "0" # strip sign off zero
    str = string(f)
    length(str) >= 2 && str[end-1:end] == ".0" ? str[1:end-2] : str
end
string_round(f) = string(f)

# REPL-specific symbols
# Anything here: https://en.wikipedia.org/wiki/Windows-1252
# should probably work fine on Windows
function math_symbol(::Type{REPLMode}, name::Symbol)
    if name == :leq
        return Compat.Sys.iswindows() ? "<=" : "≤"
    elseif name == :geq
        return Compat.Sys.iswindows() ? ">=" : "≥"
    elseif name == :eq
        return Compat.Sys.iswindows() ? "==" : "="
    elseif name == :times
        return "*"
    elseif name == :sq
        return "²"
    elseif name == :ind_open
        return "["
    elseif name == :ind_close
        return "]"
    elseif name == :for_all
        return Compat.Sys.iswindows() ? "for all" : "∀"
    elseif name == :in
        return Compat.Sys.iswindows() ? "in" : "∈"
    elseif name == :open_set
        return "{"
    elseif name == :dots
        return Compat.Sys.iswindows() ? ".." : "…"
    elseif name == :close_set
        return "}"
    elseif name == :union
        return Compat.Sys.iswindows() ? "or" : "∪"
    elseif name == :infty
        return Compat.Sys.iswindows() ? "Inf" : "∞"
    elseif name == :open_rng
        return "["
    elseif name == :close_rng
        return "]"
    elseif name == :integer
        return "integer"
    elseif name == :succeq0
        return " is semidefinite"
    elseif name == :Vert
        return Compat.Sys.iswindows() ? "||" : "‖"
    elseif name == :sub2
        return Compat.Sys.iswindows() ? "_2" : "₂"
    else
        error("Internal error: Unrecognized symbol $name.")
    end
end

# IJulia-specific symbols.
function math_symbol(::Type{IJuliaMode}, name::Symbol)
    if name == :leq
        return "\\leq"
    elseif name == :geq
        return "\\geq"
    elseif name == :eq
        return "="
    elseif name == :times
        return "\\times "
    elseif name == :sq
        return "^2"
    elseif name == :ind_open
        return "_{"
    elseif name == :ind_close
        return "}"
    elseif name == :for_all
        return "\\quad\\forall"
    elseif name == :in
        return "\\in"
    elseif name == :open_set
        return "\\{"
    elseif name == :dots
        return "\\dots"
    elseif name == :close_set
        return "\\}"
    elseif name == :union
        return "\\cup"
    elseif name == :infty
        return "\\infty"
    elseif name == :open_rng
        return "\\["
    elseif name == :close_rng
        return "\\]"
    elseif name == :integer
        return "\\in \\mathbb{Z}"
    elseif name == :succeq0
        return "\\succeq 0"
    elseif name == :Vert
        return "\\Vert"
    elseif name == :sub2
        return "_2"
    else
        error("Internal error: Unrecognized symbol $name.")
    end
end

wrap_in_math_mode(str) = "\$\$ $str \$\$"
wrap_in_inline_math_mode(str) = "\$ $str \$"

#------------------------------------------------------------------------
## Model
#------------------------------------------------------------------------
function Base.show(io::IO, model::Model) # TODO(#1180) temporary
    print(io, "A JuMP Model")
end

#------------------------------------------------------------------------
## VariableRef
#------------------------------------------------------------------------
Base.show(io::IO, v::AbstractVariableRef) = print(io, var_string(REPLMode, v))
function Base.show(io::IO, ::MIME"text/latex", v::AbstractVariableRef)
    print(io, wrap_in_math_mode(var_string(IJuliaMode, v)))
end
function var_string(::Type{REPLMode}, v::AbstractVariableRef)
    var_name = name(v)
    if !isempty(var_name)
        return var_name
    else
        return "noname"
    end
end
function var_string(::Type{IJuliaMode}, v::AbstractVariableRef)
    var_name = name(v)
    if !isempty(var_name)
        # TODO: This is wrong if variable name constains extra "]"
        return replace(replace(var_name, "[" => "_{", count = 1), "]" => "}")
    else
        return "noname"
    end
end

Base.show(io::IO, a::GenericAffExpr) = print(io, aff_string(REPLMode,a))
function Base.show(io::IO, ::MIME"text/latex", a::GenericAffExpr)
    print(io, wrap_in_math_mode(aff_string(IJuliaMode, a)))
end

function aff_string(mode, a::GenericAffExpr, show_constant=true)
    # If the expression is empty, return the constant (or 0)
    if length(linear_terms(a)) == 0
        return show_constant ? string_round(a.constant) : "0"
    end

    term_str = Array{String}(undef, 2 * length(linear_terms(a)))
    elm = 1
    # For each non-zero for this model
    for (coef, var) in linear_terms(a)
        is_zero_for_printing(coef) && continue  # e.g. x - x

        pre = is_one_for_printing(coef) ? "" : string_round(abs(coef)) * " "

        term_str[2 * elm - 1] = sign_string(coef)
        term_str[2 * elm] = string(pre, var_string(mode, var))
        elm += 1
    end

    if elm == 1
        # Will happen with cancellation of all terms
        # We should just return the constant, if its desired
        return show_constant ? string_round(a.constant) : "0"
    else
        # Correction for very first term - don't want a " + "/" - "
        term_str[1] = (term_str[1] == " - ") ? "-" : ""
        ret = join(term_str[1 : 2 * (elm - 1)])
        if !is_zero_for_printing(a.constant) && show_constant
            ret = string(ret, sign_string(a.constant),
                         string_round(abs(a.constant)))
        end
        return ret
    end
end

#------------------------------------------------------------------------
## GenericQuadExpr
#------------------------------------------------------------------------
Base.show(io::IO, q::GenericQuadExpr) = print(io, quad_string(REPLMode,q))
function Base.show(io::IO, ::MIME"text/latex", q::GenericQuadExpr)
    print(io, wrap_in_math_mode(quad_string(IJuliaMode, q)))
end

function quad_string(mode, q::GenericQuadExpr)
    length(quadterms(q)) == 0 && return aff_string(mode, q.aff)

    # Odd terms are +/i, even terms are the variables/coeffs
    term_str = Array{String}(undef, 2 * length(quadterms(q)))
    elm = 1
    if length(term_str) > 0
        for (coef, var1, var2) in quadterms(q)
            is_zero_for_printing(coef) && continue  # e.g. x - x

            pre = is_one_for_printing(coef) ? "" : string_round(abs(coef)) * " "

            x = var_string(mode,var1)
            y = var_string(mode,var2)

            term_str[2 * elm - 1] = sign_string(coef)
            term_str[2 * elm] = "$pre$x"
            if x == y
                term_str[2 * elm] *= math_symbol(mode, :sq)
            else
                term_str[2 * elm] *= string(math_symbol(mode, :times), y)
            end
            if elm == 1
                # Correction for first term as there is no space
                # between - and variable coefficient/name
                term_str[1] = coef < zero(coef) ? "-" : ""
            end
            elm += 1
        end
    end
    ret = join(term_str[1 : 2 * (elm - 1)])

    aff_str = aff_string(mode, q.aff)
    if aff_str == "0"
        return ret
    else
        if aff_str[1] == '-'
            return string(ret, " - ", aff_str[2 : end])
        else
            return string(ret, " + ", aff_str)
        end
    end
end


#------------------------------------------------------------------------
## Constraints
#------------------------------------------------------------------------

function Base.show(io::IO, ref::ConstraintRef{Model})
    print(io, constraint_string(REPLMode, name(ref), constraint_object(ref)))
end
function Base.show(io::IO, ::MIME"text/latex", ref::ConstraintRef{Model})
    print(io, constraint_string(IJuliaMode, name(ref), constraint_object(ref)))
end

function function_string(print_mode, variable::AbstractVariableRef)
    return var_string(print_mode, variable)
end

function function_string(print_mode,
                         variable_vector::Vector{<:AbstractVariableRef})
    return "[" * join(var_string.(print_mode, variable_vector), ", ") * "]"
end

function function_string(print_mode, aff::GenericAffExpr)
    return aff_string(print_mode, aff)
end

function function_string(print_mode, aff_vector::Vector{<:GenericAffExpr})
    return "[" * join(aff_string.(print_mode, aff_vector), ", ") * "]"
end

function function_string(print_mode, quad::GenericQuadExpr)
    return quad_string(print_mode, quad)
end

function function_string(print_mode, quad_vector::Vector{<:GenericQuadExpr})
    return "[" * join(quad_string.(print_mode, quad_vector), ", ") * "]"
end

function in_set_string(print_mode, set::MOI.LessThan)
    return string(math_symbol(print_mode, :leq), " ", set.upper)
end

function in_set_string(print_mode, set::MOI.GreaterThan)
    return string(math_symbol(print_mode, :geq), " ", set.lower)
end

function in_set_string(print_mode, set::MOI.EqualTo)
    return string(math_symbol(print_mode, :eq), " ", set.value)
end

function in_set_string(print_mode, set::MOI.Interval)
    return string(math_symbol(print_mode, :in), " ",
                  math_symbol(print_mode, :open_rng), set.lower, ", ",
                  set.upper, math_symbol(print_mode, :close_rng))
end

# TODO: Convert back to JuMP types for sets like PSDCone.
# TODO: Consider fancy latex names for some sets. They're currently printed as
# regular text in math mode which looks a bit awkward.
function in_set_string(print_mode, set::MOI.AbstractSet)
    return string(math_symbol(print_mode, :in), " ", set)
end

# constraint_object is a JuMP constraint object like AffExprConstraint.
# Assumes a .func and .set member.
function constraint_string(print_mode, constraint_name, constraint_object)
    func_str = function_string(print_mode, constraint_object.func)
    in_set_str = in_set_string(print_mode, constraint_object.set)
    constraint_without_name = func_str * " " * in_set_str
    if print_mode == IJuliaMode
        constraint_without_name = wrap_in_inline_math_mode(constraint_without_name)
    end
    if isempty(constraint_name)
        return constraint_without_name
    else
        return constraint_name * " : " * constraint_without_name
    end
end

#------------------------------------------------------------------------
## NonlinearExprData
#------------------------------------------------------------------------
function nl_expr_string(model::Model, mode, c::NonlinearExprData)
    return string(tape_to_expr(model, 1, c.nd, adjmat(c.nd), c.const_values, [],
                               [], model.nlp_data.user_operators, false, false,
                               mode))
end

#------------------------------------------------------------------------
## NonlinearConstraint
#------------------------------------------------------------------------
const NonlinearConstraintRef = ConstraintRef{Model, NonlinearConstraintIndex}

function Base.show(io::IO, c::NonlinearConstraintRef)
    print(io, nl_constraint_string(c.m, REPLMode,
                                   c.m.nlp_data.nlconstr[c.index.value]))
end

function Base.show(io::IO, ::MIME"text/latex", c::NonlinearConstraintRef)
    constraint = c.m.nlp_data.nlconstr[c.index.value]
    print(io, wrap_in_math_mode(nl_constraint_string(c.m, IJuliaMode,
                                                    constraint)))
end

# TODO: Printing is inconsistent between regular constraints and nonlinear
# constraints because nonlinear constraints don't have names.
function nl_constraint_string(model::Model, mode, c::NonlinearConstraint)
    s = sense(c)
    nl = nl_expr_string(model, mode, c.terms)
    if s == :range
        out_str = "$(string_round(c.lb)) " * math_symbol(mode, :leq) * " $nl " *
                  math_symbol(mode, :leq) * " " * string_round(c.ub)
    else
        if s == :<=
            rel = math_symbol(mode, :leq)
        elseif s == :>=
            rel = math_symbol(mode, :geq)
        else
            rel = math_symbol(mode, :eq)
        end
        out_str = string(nl," ",rel," ",string_round(rhs(c)))
    end
    return out_str
end

#------------------------------------------------------------------------
## Nonlinear expression/parameter reference
#------------------------------------------------------------------------
function Base.show(io::IO, ex::NonlinearExpression)
    Base.show(io, "Reference to nonlinear expression #$(ex.index)")
end
function Base.show(io::IO, p::NonlinearParameter)
    Base.show(io, "Reference to nonlinear parameter #$(p.index)")
end
