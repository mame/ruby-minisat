require 'mkmf'

CONFIG["CXX"] ||= "g++"
MINISAT_DIR = File.join(File.dirname(__FILE__), "../../minisat/MiniSat_v1.14")

minisat_include, _ = dir_config("minisat", MINISAT_DIR, "")
$objs = ["minisat.o", "minisat-wrap.o", minisat_include + "/Solver.o"]

create_makefile("minisat") if have_library("stdc++")
