require "test/unit"
require "rubygems"
require "minisat"

class TestMiniSat < Test::Unit::TestCase
  def setup
    @solver = MiniSat::Solver.new
  end

  def test_variable_pos
    var = @solver.new_var
    assert_nothing_raised { +var }
  end

  def test_variable_neg
    var = @solver.new_var
    assert_nothing_raised { -var }
  end

  def test_variable_value
    var1 = @solver.new_var
    var2 = @solver.new_var
    assert_raise(RuntimeError) { var1.value }
    @solver << var1 << -var2
    @solver.solve
    assert_equal(true , var1.value)
    assert_equal(false, var2.value)
  end

  def test_solver_add_clause
    var1 = @solver.new_var
    var2 = @solver.new_var
    @solver.add_clause(-var1, -var2)
    @solver.add_clause(var1)
    @solver.solve
    assert_equal(true , var1.value)
    assert_equal(false, var2.value)
  end

  def test_solver_add_clause_2
    var1 = @solver.new_var
    var2 = @solver.new_var
    @solver << [-var1, -var2] << var1
    @solver.solve
    assert_equal(true , var1.value)
    assert_equal(false, var2.value)
  end

  def test_solver_result
    var1 = @solver.new_var
    var2 = @solver.new_var
    @solver << [-var1, -var2] << var1
    @solver.solve
    assert_equal(@solver[var1], var1.value)
    assert_equal(@solver[var2], var2.value)
  end

  def test_solver_clause_size
    var1 = @solver.new_var
    var2 = @solver.new_var
    assert_equal(0, @solver.clause_size)
    @solver << [-var1, -var2]
    assert_equal(1, @solver.clause_size)
    @solver << var1
    assert_equal(2, @solver.clause_size)
  end

  def test_solver_satisfied?
    assert_equal(false, @solver.satisfied?)
    var = @solver.new_var
    @solver << var
    @solver.solve
    assert_equal(true, @solver.satisfied?)
    @solver << -var
    @solver.solve
    assert_equal(false, @solver.satisfied?)
  end

  def test_solver_simplify_db
    @solver.solve
    assert_nothing_raised { @solver.simplify_db }
  end

  def test_solver_solve
    var1 = @solver.new_var
    var2 = @solver.new_var
    @solver << [var1, var2]
    assert_equal(false, @solver.solve(-var1, -var2))
    assert_equal(true , @solver.solve(-var1))
    assert_equal(false, var1.value)
    assert_equal(true , var2.value)
  end

  def test_solver_solved?
    assert_equal(false, @solver.solved?)
    var = @solver.new_var
    @solver << var
    @solver.solve
    assert_equal(true, @solver.solved?)
    @solver << -var
    @solver.solve
    assert_equal(true, @solver.solved?)
  end

  def test_var_size
    assert_equal(0, @solver.var_size)
    var1 = @solver.new_var
    assert_equal(1, @solver.var_size)
    var2 = @solver.new_var
    assert_equal(2, @solver.var_size)
  end

  def test_senario1
    a = @solver.new_var
    b = @solver.new_var
    
    @solver << [a, b] << [-a, b] << [a, -b]
    
    assert_equal(true, @solver.solve)
    assert_equal(true, @solver[a])
    assert_equal(true, @solver[b])
  end

  def test_senario2
    a = @solver.new_var
    b = @solver.new_var
    
    @solver << [-a, -b] << [-a, b] << [a, -b]
    
    assert_equal(true, @solver.solve)
    assert_equal(false, @solver[a])
    assert_equal(false, @solver[b])
  end

  def test_senario3
    a = @solver.new_var
    b = @solver.new_var
    
    @solver << [a, b] << [-a, b] << [a, -b] << [-a, -b]
    
    assert_equal(false, @solver.solve)
  end
end
