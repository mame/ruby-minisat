/******************************************************************************

  ruby-minisat -- ruby binding for MiniSat

*******************************************************************************

The MIT License

Copyright (c) 2007, 2010 Yusuke Endoh

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

******************************************************************************/

/*
 * Author:: Yusuke Endoh
 * Date:: 2010/07/07
 * Copyright:: Copyright (c) 2007, 2010 Yusuke Endoh
 */

#include "ruby.h"
#include "minisat.h"

VALUE rb_mMiniSat, rb_cSolver, rb_cVariable, rb_cLiteral;

static const rb_data_type_t minisat_solver_data_type;

#define SATISFIED                       0 /* satisfied */
#define NOT_SOLVED_YET                  1 /* not solved yet */
#define UNSATISFIABLE                   2 /* always unsatisfiable */
#define UNSATISFIABLE_UNDER_ASSUMPTIONS 3 /* unsatisfiable under assumptions */

/***** type def **************************************************************/

typedef struct csolver_tag {
    wrap_solver *solver;
    int result;
    int clause_count;
} csolver;

typedef struct cvariable_tag {
    int value;
    VALUE solver;
} cvariable;

static void check_model_available(int result, int check_only_unsatisfied)
{
    switch(result) {
        case NOT_SOLVED_YET:
            if(!check_only_unsatisfied) {
              rb_raise(rb_eRuntimeError, "not solved yet");
            }
            break;
        case UNSATISFIABLE:
            rb_raise(rb_eRuntimeError, "unsatisfied");
            break;
        case UNSATISFIABLE_UNDER_ASSUMPTIONS:
            if(!check_only_unsatisfied) {
              rb_raise(rb_eRuntimeError, "unsatisfied under assumption");
            }
            break;
    }
}


/***** variable **************************************************************/

static void value_free(void *ptr)
{
    cvariable *cvar = (cvariable *)ptr;
    free(cvar);
}

static void value_mark(void *ptr)
{
    cvariable *cval = (cvariable *)ptr;
    rb_gc_mark(cval->solver);
}

static size_t value_memsize(const void *ptr)
{
    return sizeof(cvariable);
}

static const rb_data_type_t minisat_value_data_type = {
    "minisat_value",
    { value_mark, value_free, value_memsize, },
     0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};

/*
 *  call-seq:
 *     +variable   -> Literal
 *
 *  Returns positive literal of variable.
 *
 */
static VALUE variable_pos(VALUE rvar)
{
    cvariable *cvar, *clit;
    VALUE rlit;

    TypedData_Get_Struct(rvar, cvariable, &minisat_value_data_type, cvar);
    rlit = TypedData_Make_Struct(rb_cLiteral, cvariable, &minisat_value_data_type, clit);
    clit->value = wrap_lit_pos_var(cvar->value);
    clit->solver = cvar->solver;

    return rlit;
}

/*
 *  call-seq:
 *     -variable   -> Literal
 *
 *  Returns negative literal of variable.
 *
 */
static VALUE variable_neg(VALUE rvar)
{
    cvariable *cvar, *clit;
    VALUE rlit;

    TypedData_Get_Struct(rvar, cvariable, &minisat_value_data_type, cvar);
    rlit = TypedData_Make_Struct(rb_cLiteral, cvariable, &minisat_value_data_type, clit);
    clit->value = wrap_lit_neg_var(cvar->value);
    clit->solver = cvar->solver;

    return rlit;
}

/*
 *  call-seq:
 *     variable.value   -> true or false
 *
 *  Returns an assignment if the SAT is satisfiable.  Raises an exception when
 *  the SAT is not satisfied.
 *
 */
static VALUE variable_value(VALUE rvar)
{
    cvariable *cvar;
    csolver *cslv;

    TypedData_Get_Struct(rvar, cvariable, &minisat_value_data_type, cvar);
    TypedData_Get_Struct(cvar->solver, csolver, &minisat_solver_data_type, cslv);
    check_model_available(cslv->result, 0);
    switch(wrap_solver_ref_var(cslv->solver, cvar->value)) {
        case 0: return Qfalse;
        case 1: return Qtrue;
    }

    return Qnil;
}

static void convert_lits(int *lits, int argc, VALUE *argv, VALUE rslv)
{
    int i;
    VALUE rval;
    cvariable *cval;

    for(i = 0; i < argc; i++) {
        rval = argv[i];
        if(!rb_typeddata_is_kind_of(rval, &minisat_value_data_type)) {
            rb_raise(rb_eTypeError,
                     "wrong argument type %s (expected Variable or Literal)",
                     rb_obj_classname(rval));
        }
        TypedData_Get_Struct(rval, cvariable, &minisat_value_data_type,cval);
        if(cval->solver != rslv) {
            rb_raise(rb_eArgError,
                     "Variable or Literal of different solver");
        }
        lits[i] = (CLASS_OF(rval) == rb_cVariable) ?
                     wrap_lit_pos_var(cval->value) : cval->value;
    }
}


/***** solver ****************************************************************/

static void solver_free(void *ptr)
{
    csolver *cslv = (csolver *)ptr;
    wrap_solver_free(cslv->solver);
    free(cslv);
}

static size_t solver_memsize(const void *ptr)
{
    const csolver *cslv = (const csolver *)ptr;
    return sizeof(csolver) + wrap_solver_memsize(cslv->solver);
}

static const rb_data_type_t minisat_solver_data_type = {
    "minisat_solver",
    { NULL, solver_free, solver_memsize, },
     0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};

static VALUE solver_alloc(VALUE klass)
{
    csolver *cslv;
    VALUE rslv;

    rslv = TypedData_Make_Struct(klass, csolver, &minisat_solver_data_type, cslv);
    cslv->solver = wrap_solver_new();
    cslv->result = NOT_SOLVED_YET;

    return rslv;
}

/*
 *  call-seq:
 *     solver.new_var   -> Variable
 *
 *  Returns new variable for constructing SAT formula.  Raises an exception when
 *  the SAT is already prove to be always unsatisfiable.
 *
 */
static VALUE solver_new_var(VALUE rslv)
{
    csolver *cslv;
    cvariable *cvar;
    VALUE rvar;

    TypedData_Get_Struct(rslv, csolver, &minisat_solver_data_type, cslv);
    check_model_available(cslv->result, 1);
    rvar =
      TypedData_Make_Struct(rb_cVariable, cvariable, &minisat_value_data_type, cvar);
    cvar->value = wrap_solver_new_var(cslv->solver);
    cvar->solver = rslv;
    cslv->result = NOT_SOLVED_YET;

    return rvar;
}

/*
 *  call-seq:
 *     solver.add_clause(var, lit,...)   -> solver
 *
 *  Adds clause consisting of the literals to the SAT and returns solver
 *  itself.  If Variables are passed, they are handled as its positive Literal.
 *  The SAT may be automatically proved to be always unsatisfiable just after
 *  the clause added.  In the case, <code>solver.solved?</code> becomes to
 *  return true.
 *
 *     solver.add_clause(a, b, -c)  # add clause: (a or b or not c)
 *
 */
static VALUE solver_add_clause(int argc, VALUE *argv, VALUE rslv)
{
    csolver *cslv;
    int *lits;
    VALUE lits_val;

    TypedData_Get_Struct(rslv, csolver, &minisat_solver_data_type, cslv);
    lits = (int *)RB_ALLOCV_N(int, lits_val, argc);
    convert_lits(lits, argc, argv, rslv);
    if(!wrap_solver_add_clause(cslv->solver, lits, argc)) {
        cslv->result = UNSATISFIABLE;
    }
    else {
        cslv->result = NOT_SOLVED_YET;
        cslv->clause_count++;
    }

    RB_GC_GUARD(lits_val);

    return rslv;
}

/*
 *  call-seq:
 *     solver << var_or_lit_or_ary   -> solver
 *
 *  Almost same as Solver#add_caluse.  This method receives Array of Variable
 *  or Literal.
 *
 *     solver << a          # equivalent to solver.add_clause(a)
 *     solver << [a, b, -c] # equivalent to solver.add_clause(a, b, -c)
 *
 */
static VALUE solver_add_clause_2(VALUE rslv, VALUE rcls)
{
    if(rb_typeddata_is_kind_of(rcls, &minisat_value_data_type)) {
      return solver_add_clause(1, &rcls, rslv);
    }
    else {
      rcls = rb_convert_type(rcls, T_ARRAY, "Array", "to_ary");
      return solver_add_clause((int) RARRAY_LEN(rcls), RARRAY_PTR(rcls), rslv);
    }
}

/*
 *  call-seq:
 *     solver[var]   -> true or false
 *
 *  Returns a value of specified variable if the SAT is satisfied.  Raises an
 *  exception if not.
 *
 */
static VALUE solver_ref_var(VALUE rslv, VALUE rvar)
{
    csolver *cslv;
    cvariable *cvar;

    TypedData_Get_Struct(rslv, csolver, &minisat_solver_data_type, cslv);
    if(CLASS_OF(rvar) != rb_cVariable) {
        rb_raise(rb_eTypeError,
                 "wrong argument type %s (expected Variable)",
                 rb_obj_classname(rvar));
    }
    check_model_available(cslv->result, 0);
    TypedData_Get_Struct(rvar, cvariable, &minisat_value_data_type, cvar);
    switch(wrap_solver_ref_var(cslv->solver, cvar->value)) {
        case 0: return Qfalse;
        case 1: return Qtrue;
    }

    return Qnil;
}

/*
 *  call-seq:
 *     solver.solve   -> true or false
 *
 *  Determines whether the SAT is satisfiable or not.  Returns true if the SAT
 *  is satisfied, false otherwise.
 *
 */
static VALUE solver_solve(int argc, VALUE *argv, VALUE rslv)
{
    csolver *cslv;
    int *lits;
    VALUE lits_val;

    TypedData_Get_Struct(rslv, csolver, &minisat_solver_data_type, cslv);
    lits = (int *)RB_ALLOCV_N(int, lits_val, argc);
    convert_lits(lits, argc, argv, rslv);
    if(wrap_solver_solve(cslv->solver, lits, argc)) {
        cslv->result = SATISFIED;
        return Qtrue;
    }
    else {
        cslv->result =
          argc == 0 ? UNSATISFIABLE : UNSATISFIABLE_UNDER_ASSUMPTIONS;
        return Qfalse;
    }
    RB_GC_GUARD(lits_val);
}

/*
 *  call-seq:
 *     solver.simplify    -> true or false
 *
 *  Detects conflicts independent of the assumptions.  This is useful when the
 *  same SAT is solved many times under some different assumptions.
 *  Solver#simplify_db is deprecated.
 *
 */
static VALUE solver_simplify(VALUE rslv)
{
    csolver *cslv;

    TypedData_Get_Struct(rslv, csolver, &minisat_solver_data_type, cslv);

    check_model_available(cslv->result, 0);
    if(!wrap_solver_simplify(cslv->solver)) {
        cslv->result = UNSATISFIABLE;
        return Qfalse;
    }

    return Qtrue;
}

/*
 *  call-seq:
 *     solver.simplify_db    -> true or false
 *
 *  Deprecated. The same as Solver#simplify.
 *
 */
static VALUE solver_simplify_db(VALUE rslv)
{
    return solver_simplify(rslv);
}

/*
 *  call-seq:
 *     solver.var_size   -> integer
 *
 *  Returns the count of defined variables.
 *
 */
static VALUE solver_var_size(VALUE rslv)
{
    csolver *cslv;

    TypedData_Get_Struct(rslv, csolver, &minisat_solver_data_type, cslv);

    return LONG2NUM(wrap_solver_var_size(cslv->solver));
}

/*
 *  call-seq:
 *     solver.clause_size   -> integer
 *
 *  Returns the count of added clauses.
 *
 */
static VALUE solver_clause_size(VALUE rslv)
{
    csolver *cslv;

    TypedData_Get_Struct(rslv, csolver, &minisat_solver_data_type, cslv);

    return LONG2NUM(cslv->clause_count);
}

/*
 *  call-seq:
 *     solver.to_s   -> string
 *
 *  Creates a printable version of solver.
 *
 *     p solver  #=> #<MiniSat::Solver:0xb7d3c1d0 not solved yet>
 *     p solver  #=> #<MiniSat::Solver:0xb7d3c1d0 satisfied>
 *     p solver  #=> #<MiniSat::Solver:0xb7d3c1d0 unsatisfiable>
 */
static VALUE solver_to_s(VALUE rslv)
{
    const char *cname = rb_obj_classname(rslv);
    const char *msg = NULL;
    csolver *cslv;

    TypedData_Get_Struct(rslv, csolver, &minisat_solver_data_type, cslv);
    switch(cslv->result) {
        case NOT_SOLVED_YET:
            msg = "not solved yet";
            break;
        case SATISFIED:
            msg = "satisfied";
            break;
        case UNSATISFIABLE:
            msg = "unsatisfiable";
            break;
        case UNSATISFIABLE_UNDER_ASSUMPTIONS:
            msg = "unsatisfiable under assumptions";
            break;
    }

    return rb_sprintf("#<%s:%p %s", cname, (void*)rslv, msg);
}

/*
 *  call-seq:
 *     solver.solved?   -> true or false
 *
 *  Returns true if the SAT is solved, or false if not.
 *
 */
static VALUE solver_solved_p(VALUE rslv)
{
    csolver *cslv;

    TypedData_Get_Struct(rslv, csolver, &minisat_solver_data_type, cslv);

    return (cslv->result != NOT_SOLVED_YET ? Qtrue : Qfalse);
}

/*
 *  call-seq:
 *     solver.satisfied?   -> true or false
 *
 *  Returns true if the SAT is satisfied, or false if not.
 *
 */
static VALUE solver_satisfied_p(VALUE rslv)
{
    csolver *cslv;

    TypedData_Get_Struct(rslv, csolver, &minisat_solver_data_type, cslv);

    return (cslv->result == SATISFIED ? Qtrue : Qfalse);
}


void Init_minisat()
{
    rb_mMiniSat = rb_define_module("MiniSat");

    rb_cSolver = rb_define_class_under(rb_mMiniSat, "Solver", rb_cObject);
    rb_define_alloc_func(rb_cSolver, solver_alloc);
    rb_define_method(rb_cSolver, "new_var", solver_new_var, 0);
    rb_define_method(rb_cSolver, "add_clause", solver_add_clause, -1);
    rb_define_method(rb_cSolver, "<<", solver_add_clause_2, 1);
    rb_define_method(rb_cSolver, "[]", solver_ref_var, 1);
    rb_define_method(rb_cSolver, "solve", solver_solve, -1);
    rb_define_method(rb_cSolver, "simplify", solver_simplify, 0);
    rb_define_method(rb_cSolver, "simplify_db", solver_simplify_db, 0);
    rb_define_method(rb_cSolver, "var_size", solver_var_size, 0);
    rb_define_method(rb_cSolver, "clause_size", solver_clause_size, 0);
    rb_define_method(rb_cSolver, "to_s", solver_to_s, 0);
    rb_define_method(rb_cSolver, "solved?", solver_solved_p, 0);
    rb_define_method(rb_cSolver, "satisfied?", solver_satisfied_p, 0);

    rb_cVariable = rb_define_class_under(rb_mMiniSat, "Variable", rb_cObject);
    rb_undef_method(CLASS_OF(rb_cVariable), "new");
    rb_undef_alloc_func(rb_cVariable);
    rb_define_method(rb_cVariable, "+@", variable_pos, 0);
    rb_define_method(rb_cVariable, "-@", variable_neg, 0);
    rb_define_method(rb_cVariable, "value", variable_value, 0);

    rb_cLiteral = rb_define_class_under(rb_mMiniSat, "Literal", rb_cObject);
    rb_undef_method(CLASS_OF(rb_cLiteral), "new");
    rb_undef_alloc_func(rb_cLiteral);
}
