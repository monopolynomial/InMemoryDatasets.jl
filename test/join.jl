
using Test, InMemoryDatasets, Random, CategoricalArrays, PooledArrays
const ≅ = isequal

isequal_coltyped(ds1::AbstractDataset, ds2::AbstractDataset) =
    isequal(ds1, ds2) && typeof.(eachcol(ds1)) == typeof.(eachcol(ds2))

name = Dataset(ID = Union{Int, Missing}[1, 2, 3],
                Name = Union{String, Missing}["John Doe", "Jane Doe", "Joe Blogs"])
job = Dataset(ID = Union{Int, Missing}[1, 2, 2, 4],
                Job = Union{String, Missing}["Lawyer", "Doctor", "Florist", "Farmer"])

# Test output of various join types
outer = Dataset(ID = [1, 2, 2, 3, 4],
                  Name = ["John Doe", "Jane Doe", "Jane Doe", "Joe Blogs", missing],
                  Job = ["Lawyer", "Doctor", "Florist", missing, "Farmer"])

# (Tests use current column ordering but don't promote it)
right = outer[Bool[!ismissing(x) for x in outer.Job], [:ID, :Name, :Job]]
left = outer[Bool[!ismissing(x) for x in outer.Name], :]
inner = left[Bool[!ismissing(x) for x in left.Job], :]
semi = unique(inner[:, [:ID, :Name]])
anti = left[Bool[ismissing(x) for x in left.Job], [:ID, :Name]]

classA = Dataset(id = ["id1", "id2", "id3", "id4", "id5"],
                        mark = [50, 69.5, 45.5, 88.0, 98.5])
grades = Dataset(mark = [0, 49.5, 59.5, 69.5, 79.5, 89.5, 95.5],
                        grade = ["F", "P", "C", "B", "A-", "A", "A+"])
closeone = Dataset(id = ["id1", "id2", "id3", "id4", "id5"],
                        mark = [50, 69.5, 45.5, 88.0, 98.5],
                        grade = ["P", "B", "F", "A-", "A+"])
trades = Dataset(
                [["20160525 13:30:00.023",
                  "20160525 13:30:00.038",
                  "20160525 13:30:00.048",
                  "20160525 13:30:00.048",
                  "20160525 13:30:00.048"],
                ["MSFT", "MSFT",
                 "GOOG", "GOOG", "AAPL"],
                [51.95, 51.95,
                 720.77, 720.92, 98.00],
                [75, 155,
                 100, 100, 100]],
               ["time", "ticker", "price", "quantity"]);
modify!(trades, 1 => byrow(x -> DateTime(x, dateformat"yyyymmdd HH:MM:SS.s")));
quotes = Dataset(
              [["20160525 13:30:00.023",
                "20160525 13:30:00.023",
                "20160525 13:30:00.030",
                "20160525 13:30:00.041",
                "20160525 13:30:00.048",
                "20160525 13:30:00.049",
                "20160525 13:30:00.072",
                "20160525 13:30:00.075"],
              ["GOOG", "MSFT", "MSFT", "MSFT",
               "GOOG", "AAPL", "GOOG", "MSFT"],
              [720.50, 51.95, 51.97, 51.99,
               720.50, 97.99, 720.50, 52.01],
              [720.93, 51.96, 51.98, 52.00,
               720.93, 98.01, 720.88, 52.03]],
             ["time", "ticker", "bid", "ask"]);
modify!(quotes, 1 => byrow(x -> DateTime(x, dateformat"yyyymmdd HH:MM:SS.s")));
closefinance1 = Dataset([Union{Missing, DateTime}[DateTime("2016-05-25T13:30:00.023"), DateTime("2016-05-25T13:30:00.038"), DateTime("2016-05-25T13:30:00.048"), DateTime("2016-05-25T13:30:00.048"), DateTime("2016-05-25T13:30:00.048")],
     Union{Missing, String}["MSFT", "MSFT", "GOOG", "GOOG", "AAPL"],
     Union{Missing, Float64}[51.95, 51.95, 720.77, 720.92, 98.0],
     Union{Missing, Int64}[75, 155, 100, 100, 100],
     Union{Missing, String}["MSFT", "MSFT", "GOOG", "GOOG", "GOOG"],
     Union{Missing, Float64}[51.95, 51.97, 720.5, 720.5, 720.5],
     Union{Missing, Float64}[51.96, 51.98, 720.93, 720.93, 720.93]],["time", "ticker", "price", "quantity", "ticker_1", "bid", "ask"])

@testset "general usage" begin
    # Join on symbols or vectors of symbols
    innerjoin(name, job, on = :ID)
    innerjoin(name, job, on = [:ID])

    @test_throws ArgumentError innerjoin(name, job)
    @test_throws MethodError innerjoin(name, job, on = :ID, matchmissing=:errors)
    @test_throws MethodError outerjoin(name, job, on = :ID, matchmissing=:notequal)

    @test innerjoin(name, job, on = :ID) == inner
    @test outerjoin(name, job, on = :ID) == outer
    @test leftjoin(name, job, on = :ID) == left
    @test semijoin(name, job, on = :ID) == semi
    @test antijoin(name, job, on = :ID) == anti
    @test closejoin(classA, grades, on = :mark) == closeone
    @test closejoin(trades, quotes, on = :time, makeunique = true) == closefinance1

    # Join with no non-key columns
    on = [:ID]
    nameid = name[:, on]
    jobid = job[:, on]

    @test innerjoin(nameid, jobid, on = :ID) == inner[:, on]
    @test outerjoin(nameid, jobid, on = :ID) == outer[:, on]
    @test leftjoin(nameid, jobid, on = :ID) == left[:, on]
    @test semijoin(nameid, jobid, on = :ID) == semi[:, on]
    @test antijoin(nameid, jobid, on = :ID) == anti[:, on]

    # Join on multiple keys
    ds1 = Dataset(A = 1, B = 2, C = 3)
    ds2 = Dataset(A = 1, B = 2, D = 4)

    @test innerjoin(ds1, ds2, on = [:A, :B]) == Dataset(A = 1, B = 2, C = 3, D = 4)

    dsl = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
         Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
         Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
         Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]], ["x1", "x2", "x3", "row"])
    dsr = Dataset(x1=[1, 3], y =[100.0, 200.0])
    setformat!(dsl, 1=>iseven)
    setformat!(dsr, 1=>isodd)

    left1 = leftjoin(dsl, dsr, on = :x1)
    left1_t = Dataset([Union{Missing, Int64}[10, 10, 3, 4, 4, 1, 5, 5, 6, 6, 7, 2, 2, 10, 10],
           Union{Missing, Int64}[10, 10, 3, 4, 4, 1, 5, 5, 6, 6, 7, 2, 2, 10, 10],
           Union{Missing, Int64}[3, 3, 6, 7, 7, 10, 10, 5, 10, 10, 9, 1, 1, 1, 1],
           Union{Missing, Int64}[1, 1, 2, 3, 3, 4, 5, 6, 7, 7, 8, 9, 9, 10, 10],
           Union{Missing, Float64}[100.0, 200.0, missing, 100.0, 200.0, missing, missing, missing, 100.0, 200.0, missing, 100.0, 200.0, 100.0, 200.0]], ["x1", "x2", "x3", "row", "y"])
    left2 = leftjoin(dsl, dsr, on = :x1, mapformats = [true, false])
    left2_t = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[100.0, missing, 100.0, missing, missing, missing, 100.0, missing, 100.0, 100.0]], ["x1", "x2", "x3", "row", "y"])
    left3 = leftjoin(dsl, dsr, on = :x1, mapformats = [false, true])
    left3_t = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[missing, missing, missing, 100.0, 200.0, missing, missing, missing, missing, missing, missing]], ["x1", "x2", "x3", "row", "y"])
    left4 = leftjoin(dsl, dsr, on = :x1, mapformats = [false, false])
    left4_t = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[missing, 200.0, missing, 100.0, missing, missing, missing, missing, missing, missing]], ["x1", "x2", "x3", "row", "y"])
    inner1 = innerjoin(dsl, dsr, on = :x1)
    inner1_t = Dataset([Union{Missing, Int64}[10, 10, 4, 4, 6, 6, 2, 2, 10, 10],
           Union{Missing, Int64}[10, 10, 4, 4, 6, 6, 2, 2, 10, 10],
           Union{Missing, Int64}[3, 3, 7, 7, 10, 10, 1, 1, 1, 1],
           Union{Missing, Int64}[1, 1, 3, 3, 7, 7, 9, 9, 10, 10],
           Union{Missing, Float64}[100.0, 200.0, 100.0, 200.0, 100.0, 200.0, 100.0, 200.0, 100.0, 200.0]], ["x1", "x2", "x3", "row", "y"])
    inner2 = innerjoin(dsl, dsr, on = :x1, mapformats = [true, false])
    inner2_t = Dataset([ Union{Missing, Int64}[10, 4, 6, 2, 10],
           Union{Missing, Int64}[10, 4, 6, 2, 10],
           Union{Missing, Int64}[3, 7, 10, 1, 1],
           Union{Missing, Int64}[1, 3, 7, 9, 10],
           Union{Missing, Float64}[100.0, 100.0, 100.0, 100.0, 100.0]], ["x1", "x2", "x3", "row", "y"])
    inner3 = innerjoin(dsl, dsr, on = :x1, mapformats = [false, true])
    inner3_t = Dataset([Union{Missing, Int64}[1, 1],
           Union{Missing, Int64}[1, 1],
           Union{Missing, Int64}[10, 10],
           Union{Missing, Int64}[4, 4],
           Union{Missing, Float64}[100.0, 200.0]], ["x1", "x2", "x3", "row", "y"])
    inner4 = innerjoin(dsl, dsr, on = :x1, mapformats = [false, false])
    inner4_t = Dataset([Union{Missing, Int64}[3, 1],
           Union{Missing, Int64}[3, 1],
           Union{Missing, Int64}[6, 10],
           Union{Missing, Int64}[2, 4],
           Union{Missing, Float64}[200.0, 100.0]], ["x1", "x2", "x3", "row", "y"])
    outer1 = outerjoin(dsl, dsr, on = :x1)
    outer1_t = Dataset([Union{Missing, Int64}[10, 10, 3, 4, 4, 1, 5, 5, 6, 6, 7, 2, 2, 10, 10],
           Union{Missing, Int64}[10, 10, 3, 4, 4, 1, 5, 5, 6, 6, 7, 2, 2, 10, 10],
           Union{Missing, Int64}[3, 3, 6, 7, 7, 10, 10, 5, 10, 10, 9, 1, 1, 1, 1],
           Union{Missing, Int64}[1, 1, 2, 3, 3, 4, 5, 6, 7, 7, 8, 9, 9, 10, 10],
           Union{Missing, Float64}[100.0, 200.0, missing, 100.0, 200.0, missing, missing, missing, 100.0, 200.0, missing, 100.0, 200.0, 100.0, 200.0]], ["x1", "x2", "x3", "row", "y"])
    outer2 = outerjoin(dsl, dsr, on = :x1, mapformats = [false, true])
    outer2_t = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[missing, missing, missing, 100.0, 200.0, missing, missing, missing, missing, missing, missing]], ["x1", "x2", "x3", "row", "y"])
    outer3 = outerjoin(dsl, dsr, on = :x1, mapformats = [true, false])
    outer3_t = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10, 3],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10, missing],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1, missing],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, missing],
           Union{Missing, Float64}[100.0, missing, 100.0, missing, missing, missing, 100.0, missing, 100.0, 100.0, 200.0]], ["x1", "x2", "x3", "row", "y"])
    outer4 = outerjoin(dsl, dsr, on = :x1, mapformats = [false, false])
    outer4_t = Dataset([ Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[missing, 200.0, missing, 100.0, missing, missing, missing, missing, missing, missing]], ["x1", "x2", "x3", "row", "y"])
    contains1 = contains(dsl, dsr, on = :x1)
    contains1_t = Bool[1, 0, 1, 0, 0, 0, 1, 0, 1, 1]
    contains2 = contains(dsl, dsr, on = :x1, mapformats = [true, false])
    contains2_t = Bool[1, 0, 1, 0, 0, 0, 1, 0, 1, 1]
    contains3 = contains(dsl, dsr, on = :x1, mapformats =[false, true])
    contains3_t = Bool[0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
    contains4 = contains(dsl, dsr, on = :x1, mapformats = [false, false])
    contains4_t = Bool[0, 1, 0, 1, 0, 0, 0, 0, 0, 0]

    close1 = closejoin(dsl, dsr, on = :x1)
    close1_t = Dataset([ Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[200.0, missing, 200.0, missing, missing, missing, 200.0, missing, 200.0, 200.0]], ["x1", "x2", "x3", "row", "y"])
    close2 = closejoin(dsl, dsr, on = :x1, direction = :forward)
    close2_t = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0]], ["x1", "x2", "x3", "row", "y"])
    close3 = closejoin(dsl, dsr, on = :x1, border = :nearest)
    close3_t = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[200.0, 100.0, 200.0, 100.0, 100.0, 100.0, 200.0, 100.0, 200.0, 200.0]], ["x1", "x2", "x3", "row", "y"])
    close4 = closejoin(dsl, dsr, on = :x1, mapformats = [true, false])
    close4_t = Dataset([ Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[100.0, missing, 100.0, missing, missing, missing, 100.0, missing, 100.0, 100.0]],  ["x1", "x2", "x3", "row", "y"])
    close5 = closejoin(dsl, dsr, on = :x1, mapformats = [true, false], direction = :forward)
    close5_t = Dataset([ Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0]], ["x1", "x2", "x3", "row", "y"])
    close6 = closejoin(dsl, dsr, on = :x1, mapformats = [false, true])
    close6_t = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[200.0, 200.0, 200.0, 200.0, 200.0, 200.0, 200.0, 200.0, 200.0, 200.0]], ["x1", "x2", "x3", "row", "y"])
    close7 = closejoin(dsl, dsr, on = :x1, mapformats = [false, true], direction = :forward)
    close7_t = Dataset([ Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[missing, missing, missing, 100.0, missing, missing, missing, missing, missing, missing]],["x1", "x2", "x3", "row", "y"])
    close8 = closejoin(dsl, dsr, on = :x1, mapformats = [false, true], direction = :forward, border = :nearest)
    close8_t = Dataset([ Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[200.0, 200.0, 200.0, 100.0, 200.0, 200.0, 200.0, 200.0, 200.0, 200.0]],["x1", "x2", "x3", "row", "y"])
    close9 = closejoin(dsl, dsr, on = :x1, mapformats = [false, false])
    close9_t = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[200.0, 200.0, 200.0, 100.0, 200.0, 200.0, 200.0, 200.0, 100.0, 200.0]], ["x1", "x2", "x3", "row", "y"])
    close10 = closejoin(dsl, dsr, on = :x1, mapformats = false, direction = :forward)
    close10_t = Dataset([ Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[missing, 200.0, missing, 100.0, missing, missing, missing, missing, 200.0, missing]], ["x1", "x2", "x3", "row", "y"])
    close11 = closejoin(dsl, dsr, on = :x1, mapformats = false, direction = :forward, border = :nearest)
    close11_t = Dataset([ Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
           Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
           Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
           Union{Missing, Float64}[200.0, 200.0, 200.0, 100.0, 200.0, 200.0, 200.0, 200.0, 200.0, 200.0]], ["x1", "x2", "x3", "row", "y"])
    @test left1 == left1_t
    @test left2 == left2_t
    @test left3 == left3_t
    @test left4 == left4_t
    @test inner1 == inner1_t
    @test inner2 == inner2_t
    @test inner3 == inner3_t
    @test inner4 == inner4_t
    @test outer1 == outer1_t
    @test outer2 == outer2_t
    @test outer3 == outer3_t
    @test outer4 == outer4_t
    @test contains1 == contains1_t
    @test contains2 == contains2_t
    @test contains3 == contains3_t
    @test contains4 == contains4_t
    @test close1 == close1_t
    @test close2 == close2_t
    @test close3 == close3_t
    @test close4 == close4_t
    @test close5 == close5_t
    @test close6 == close6_t
    @test close7 == close7_t
    @test close8 == close8_t
    @test close9 == close9_t
    @test close10 == close10_t
    @test close11 == close11_t

    dsl = Dataset([[Characters{1, UInt8}(randstring(1)) for _ in 1:10^5] for _ in 1:3], :auto)
    dsr = Dataset([[Characters{1, UInt8}(randstring(1)) for _ in 1:10^5] for _ in 1:3], :auto)
    left1 = leftjoin(dsl, dsr, on = [:x1, :x2], makeunique = true, accelerate = true, stable =true, check = false)
    left2 = leftjoin(dsl, dsr, on = [:x1, :x2], makeunique = true, accelerate = false, stable = true, check = false)
    @test left1 == left2
    @test unique(select!(left1, [:x1, :x2, :x3]), [:x1, :x2]) == unique(dsl, [:x1, :x2])

    dsl = Dataset([[Characters{1, UInt8}(randstring(1)) for _ in 1:10^5] for _ in 1:3], :auto)
    dsr = Dataset([[Characters{1, UInt8}(randstring(1)) for _ in 1:10^5] for _ in 1:3], :auto)
    for i in 1:3
        dsl[!, i] = PooledArray(dsl[!, i])
        dsr[!, i] = PooledArray(dsr[!, i])
    end
    for i in 1:10
        left1 = leftjoin(dsl, dsr, on = [:x1, :x2], makeunique = true, accelerate = true, stable =true, check = false)
        left2 = leftjoin(dsl, dsr, on = [:x1, :x2], makeunique = true, accelerate = false, stable = true, check = false)
        @test left1 == left2
        @test unique(select!(left1, [:x1, :x2, :x3]), [:x1, :x2]) == unique(dsl, [:x1, :x2])
    end
    x1 = rand(1:1000, 5000)
    x2 = rand(1:100, 5000)
    y = rand(5000)
    y2 = rand(5000)
    dsl = Dataset(x1 = Characters{6, UInt8}.(c"id" .* string.(x1)), x2 = Characters{5, UInt8}.(c"id" .* string.(x2)), y = y)
    dsr = Dataset(x1 = x1, x2 = x2, y2 = y2)
    fmtfun(x) = @views parse(Int, x[3:end])
    setformat!(dsl, 1:2=>fmtfun)
    semi1 = semijoin(dsl, dsr, on = [:x1, :x2])
    semi2 = semijoin(dsl, dsr, on = [:x1, :x2], accelerate = true)
    @test semi1 == dsl
    @test semi2 == dsl
    inn1 = innerjoin(dsl, dsr, on =[:x1, :x2], mapformats = [true, false], stable = true)
    out1 = outerjoin(dsl, dsr, on =[:x1, :x2], mapformats = [true, false], stable = true)
    left1 = leftjoin(dsl, dsr, on =[:x1, :x2], mapformats = [true, false], accelerate = true, stable =true)
    @test inn1 == out1 == left1
    fmtfun2(x) = c"id" * Characters{4, UInt8}(x)
    setformat!(dsr, 1:2=>fmtfun2)
    semi1 = semijoin(dsl, dsr, on = [:x1, :x2], mapformats = [false, true])
    semi2 = semijoin(dsl, dsr, on = [:x1, :x2], accelerate = true, mapformats = [false, true])
    @test semi1 == dsl
    @test semi2 == dsl
    inn1 = innerjoin(dsl, dsr, on =[:x1, :x2], mapformats = [false, true], stable = true)
    out1 = outerjoin(dsl, dsr, on =[:x1, :x2], mapformats = [false, true], stable = true)
    left1 = leftjoin(dsl, dsr, on =[:x1, :x2], mapformats = [false, true], accelerate = true, stable =true)
    @test inn1 == out1 == left1
    x1 = rand(1:1000, 5000)
    x2 = rand(1:100, 5000)
    y = rand(5000)
    y2 = rand(5000)
    dsl = Dataset(x1 = Characters{6, UInt8}.(c"id" .* string.(x1)), x2 = Characters{5, UInt8}.(c"id" .* string.(x2)), y = y)
    dsr = Dataset(x1 = x1, x2 = x2, y2 = y2)
    for i in 1:2
        dsl[!, i] = PooledArray(dsl[!, i])
        dsr[!, i] = PooledArray(dsr[!, i])
    end
    setformat!(dsl, 1:2=>fmtfun)
    semi1 = semijoin(dsl, dsr, on = [:x1, :x2], mapformats = [true, false])
    semi2 = semijoin(dsl, dsr, on = [:x1, :x2], accelerate = true, mapformats = [true, false])
    @test semi1 == dsl
    @test semi2 == dsl
    inn1 = innerjoin(dsl, dsr, on =[:x1, :x2], mapformats = [true, false], stable = true)
    out1 = outerjoin(dsl, dsr, on =[:x1, :x2], mapformats = [true, false], stable = true)
    left1 = leftjoin(dsl, dsr, on =[:x1, :x2], mapformats = [true, false], accelerate = true, stable =true)
    @test inn1 == out1 == left1
    setformat!(dsr, 1:2=>fmtfun2)
    semi1 = semijoin(dsl, dsr, on = [:x1, :x2], mapformats = [false, true])
    semi2 = semijoin(dsl, dsr, on = [:x1, :x2], accelerate = true, mapformats = [false, true])
    @test semi1 == dsl
    @test semi2 == dsl
    inn1 = innerjoin(dsl, dsr, on =[:x1, :x2], mapformats = [false, true], stable = true)
    out1 = outerjoin(dsl, dsr, on =[:x1, :x2], mapformats = [false, true], stable = true)
    left1 = leftjoin(dsl, dsr, on =[:x1, :x2], mapformats = [false, true], accelerate = true, stable =true)
    @test inn1 == out1 == left1
    x1 = -rand(1:1000, 5000)
    x2 = -rand(1:100, 5000)
    y = rand(5000)
    y2 = rand(5000)
    dsl = Dataset(x1 = Characters{6, UInt8}.(c"id" .* string.(-x1)), x2 = Characters{5, UInt8}.(c"id" .* string.(-x2)), y = y)
    dsr = Dataset(x1 = x1, x2 = x2, y2 = y2)
    for i in 1:2
        dsl[!, i] = PooledArray(dsl[!, i])
        dsr[!, i] = PooledArray(dsr[!, i])
    end
    fmtfun3(x) = @views -parse(Int, x[3:end])
    setformat!(dsl, 1:2=>fmtfun3)
    semi1 = semijoin(dsl, dsr, on = [:x1, :x2], mapformats = [true, false])
    semi2 = semijoin(dsl, dsr, on = [:x1, :x2], accelerate = true, mapformats = [true, false])
    @test semi1 == dsl
    @test semi2 == dsl
    inn1 = innerjoin(dsl, dsr, on =[:x1, :x2], mapformats = [true, false], stable = true)
    out1 = outerjoin(dsl, dsr, on =[:x1, :x2], mapformats = [true, false], stable = true)
    left1 = leftjoin(dsl, dsr, on =[:x1, :x2], mapformats = [true, false], accelerate = true, stable =true)
    @test inn1 == out1 == left1


end

@testset "Test empty inputs 1" begin
    simple_ds(len::Int, col=:A) = (ds = Dataset();
                                   ds[!, col]=Vector{Union{Int, Missing}}(1:len);
                                   ds)
    @test leftjoin(simple_ds(0), simple_ds(0), on = :A) == simple_ds(0)
    @test leftjoin(simple_ds(2), simple_ds(0), on = :A) == simple_ds(2)
    @test leftjoin(simple_ds(0), simple_ds(2), on = :A) == simple_ds(0)
    @test semijoin(simple_ds(0), simple_ds(0), on = :A) == simple_ds(0)
    @test semijoin(simple_ds(2), simple_ds(0), on = :A) == simple_ds(0)
    @test semijoin(simple_ds(0), simple_ds(2), on = :A) == simple_ds(0)
    @test antijoin(simple_ds(0), simple_ds(0), on = :A) == simple_ds(0)
    @test antijoin(simple_ds(2), simple_ds(0), on = :A) == simple_ds(2)
    @test antijoin(simple_ds(0), simple_ds(2), on = :A) == simple_ds(0)
end

@testset "Test empty inputs 2" begin
    simple_ds(len::Int, col=:A) = (ds = Dataset(); ds[!, col]=collect(1:len); ds)
    @test leftjoin(simple_ds(0), simple_ds(0), on = :A) ==  simple_ds(0)
    @test leftjoin(simple_ds(2), simple_ds(0), on = :A) ==  simple_ds(2)
    @test leftjoin(simple_ds(0), simple_ds(2), on = :A) ==  simple_ds(0)
    @test semijoin(simple_ds(0), simple_ds(0), on = :A) ==  simple_ds(0)
    @test semijoin(simple_ds(2), simple_ds(0), on = :A) ==  simple_ds(0)
    @test semijoin(simple_ds(0), simple_ds(2), on = :A) ==  simple_ds(0)
    @test antijoin(simple_ds(0), simple_ds(0), on = :A) ==  simple_ds(0)
    @test antijoin(simple_ds(2), simple_ds(0), on = :A) ==  simple_ds(2)
    @test antijoin(simple_ds(0), simple_ds(2), on = :A) ==  simple_ds(0)

end

@testset "all joins" begin
    ds1 = Dataset(A = categorical(1:50),
                    B = categorical(1:50),
                    C = 1)
    @test innerjoin(ds1, ds1, on = [:A, :B], makeunique=true)[!, 1:3] == ds1
    # Test that join works when mixing Array{Union{T, Missing}} with Array{T} (issue #1088)
    ds = Dataset(Name = Union{String, Missing}["A", "B", "C"],
                Mass = [1.5, 2.2, 1.1])
    ds2 = Dataset(Name = ["A", "B", "C", "A"],
                    Quantity = [3, 3, 2, 4])
    @test leftjoin(ds2, ds, on=:Name) == Dataset(Name = ["A", "B", "C", "A"],
                                                   Quantity = [3, 3, 2, 4],
                                                   Mass = [1.5, 2.2, 1.1, 1.5])

    # Test that join works when mixing Array{Union{T, Missing}} with Array{T} (issue #1151)
    ds = Dataset([collect(1:10), collect(2:11)], [:x, :y])
    dsmissing = Dataset(x = Vector{Union{Int, Missing}}(1:10),
                        z = Vector{Union{Int, Missing}}(3:12))
    @test innerjoin(ds, dsmissing, on = :x) ==
        Dataset([collect(1:10), collect(2:11), collect(3:12)], [:x, :y, :z])
    @test innerjoin(dsmissing, ds, on = :x) ==
        Dataset([Vector{Union{Int, Missing}}(1:10), Vector{Union{Int, Missing}}(3:12),
                collect(2:11)], [:x, :z, :y])
    ds1 = Dataset(Any[[1, 3, 5], [1.0, 3.0, 5.0]], [:id, :fid])
    ds2 = Dataset(Any[[0, 1, 2, 3, 4], [0.0, 1.0, 2.0, 3.0, 4.0]], [:id, :fid])


    i(on) = innerjoin(ds1, ds2, on = on, makeunique=true)
    l(on) = leftjoin(ds1, ds2, on = on, makeunique=true)
    o(on) = outerjoin(ds1, ds2, on = on, makeunique=true)
    s(on) = semijoin(ds1, ds2, on = on)
    a(on) = antijoin(ds1, ds2, on = on)

    @test s(:id) ==
          s(:fid) ==
          s([:id, :fid]) == Dataset([[1, 3], [1, 3]], [:id, :fid])
    @test typeof.(eachcol(s(:id))) ==
          typeof.(eachcol(s(:fid))) ==
          typeof.(eachcol(s([:id, :fid]))) == [Vector{Union{Missing, Int}}, Vector{Union{Missing, Float64}}]
    @test a(:id) ==
          a(:fid) ==
          a([:id, :fid]) == Dataset([[5], [5]], [:id, :fid])
    @test typeof.(eachcol(a(:id))) ==
          typeof.(eachcol(a(:fid))) ==
          typeof.(eachcol(a([:id, :fid]))) == [Vector{Union{Missing, Int}}, Vector{Union{Missing, Float64}}]

    on = :id
    @test i(on) == Dataset([[1, 3], [1, 3], [1, 3]], [:id, :fid, :fid_1])
    @test typeof.(eachcol(i(on))) == [Vector{Union{Missing, Int}}, Vector{Union{Missing, Float64}}, Vector{Union{Missing, Float64}}]
    @test l(on) ≅ Dataset(id = [1, 3, 5],
                            fid = [1, 3, 5],
                            fid_1 = [1, 3, missing])
    @test typeof.(eachcol(l(on))) ==
        [Vector{Union{Missing, Int}}, Vector{Union{Missing, Float64}}, Vector{Union{Float64, Missing}}]


    @test o(on) ≅ Dataset(id = [1, 3, 5, 0, 2, 4],
                            fid = [1, 3, 5, missing, missing, missing],
                            fid_1 = [1, 3, missing, 0, 2, 4])
    @test typeof.(eachcol(o(on))) ==
        [Vector{Union{Missing, Int}}, Vector{Union{Float64, Missing}}, Vector{Union{Float64, Missing}}]

    on = :fid
    @test i(on) == Dataset([[1, 3], [1.0, 3.0], [1, 3]], [:id, :fid, :id_1])
    @test typeof.(eachcol(i(on))) == [Vector{Union{Missing, Int}}, Vector{Union{Missing, Float64}}, Vector{Union{Missing, Int}}]
    @test l(on) ≅ Dataset(id = [1, 3, 5],
                            fid = [1, 3, 5],
                            id_1 = [1, 3, missing])
    @test typeof.(eachcol(l(on))) == [Vector{Union{Missing, Int}}, Vector{Union{Missing, Float64}},
                                     Vector{Union{Int, Missing}}]

    @test o(on) ≅ Dataset(id = [1, 3, 5, missing, missing, missing],
                            fid = [1, 3, 5, 0, 2, 4],
                            id_1 = [1, 3, missing, 0, 2, 4])
    @test typeof.(eachcol(o(on))) == [Vector{Union{Int, Missing}}, Vector{Union{Missing, Float64}},
                                     Vector{Union{Int, Missing}}]

    on = [:id, :fid]
    @test i(on) == Dataset([[1, 3], [1, 3]], [:id, :fid])
    @test typeof.(eachcol(i(on))) == [Vector{Union{Missing, Int}}, Vector{Union{Missing, Float64}}]
    @test l(on) == Dataset(id = [1, 3, 5], fid = [1, 3, 5])
    @test typeof.(eachcol(l(on))) == [Vector{Union{Missing, Int}}, Vector{Union{Missing, Float64}}]

    @test o(on) == Dataset(id = [1, 3, 5, 0, 2, 4], fid = [1, 3, 5, 0, 2, 4])
    @test typeof.(eachcol(o(on))) == [Vector{Union{Missing, Int}}, Vector{Union{Missing, Float64}}]
    dsl = Dataset(x=[1,2], y=[3,4])
    re = innerjoin(dsl, dsl, on = [:x=>:y], makeunique = true)
    @test Dataset([[],[],[]], names(re)) == re


    dsl = Dataset(x1 = [1,2,3,4,5,6], x2= [1,1,1,2,2,2])
    dsr = Dataset(x1 = [1,1,1,4,5,7],x2= [1,1,3,4,5,6], y = [343,54,54,464,565,7567])
    cj = closejoin(dsl, dsr, on = [:x1, :x2])
    cj_t = Dataset([Union{Missing, Int64}[1, 2, 3, 4, 5, 6],
         Union{Missing, Int64}[1, 1, 1, 2, 2, 2],
         Union{Missing, Int64}[54, missing, missing, missing, missing, missing]], ["x1", "x2", "y"])
    @test cj == cj_t
    cj = closejoin(dsl, dsr, on = [:x1, :x2], direction = :forward)
    cj_t = Dataset([ Union{Missing, Int64}[1, 2, 3, 4, 5, 6],
         Union{Missing, Int64}[1, 1, 1, 2, 2, 2],
         Union{Missing, Int64}[343, missing, missing, 464, 565, missing]],["x1", "x2", "y"] )
    @test cj == cj_t
    dsl = Dataset(x1 = [Date(2020,11,6), Date(2021,2,24), Date(2021,1,17), Date(2013,5,12)], val = [66,77,88,99])
    dsr = Dataset(x1 = [Date(2010,11,2), Date(2012, 5, 3), Date(2010, 2,2)], x2 = [1,2,3])
    setformat!(dsl, 1=>month)
    setformat!(dsr, 1=>month)
    out_l1 = leftjoin(dsl, dsr, on = :x1, mapformats = false)
    out_l2 = leftjoin(dsl, dsr, on = :x1, mapformats = true)
    out_t1 = Dataset([Union{Missing, Date}[Date("2020-11-06"), Date("2021-02-24"), Date("2021-01-17"), Date("2013-05-12")],
             Union{Missing, Int64}[66, 77, 88, 99],
             Union{Missing, Int64}[missing, missing, missing, missing]], [:x1, :val, :x2])
    out_t2 = Dataset([Union{Missing, Date}[Date("2020-11-06"), Date("2021-02-24"), Date("2021-01-17"), Date("2013-05-12")],
             Union{Missing, Int64}[66, 77, 88, 99],
             Union{Missing, Int64}[1, 3, missing, 2]], [:x1, :val, :x2])
    @test out_l1 == out_t1
    @test out_l2 == out_t2
    dsl = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
         Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
         Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
         Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]], ["x1", "x2", "x3", "row"])
    dsr = Dataset(x1=[1, 3, 2], y =[100.0, 200.0, 300.0])
    setformat!(dsr, 1=>isodd)

    left1 = leftjoin(dsl, dsr, on = :x1, mapformats = false)
    left1_t = Dataset([Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
             Union{Missing, Int64}[10, 3, 4, 1, 5, 5, 6, 7, 2, 10],
             Union{Missing, Int64}[3, 6, 7, 10, 10, 5, 10, 9, 1, 1],
             Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
             Union{Missing, Float64}[missing, 200.0, missing, 100.0, missing, missing, missing, missing, 300.0, missing]], ["x1", "x2", "x3", "row", "y"])
    @test left1 == left1_t


    A = Dataset(a = [1, 2, 3], b = ["a", "b", "c"])
    B = Dataset(b = ["a", "b", "c"], c = CategoricalVector(["a", "b", "b"]))
    levels!(B.c.val, ["b", "a"])
    @test levels(innerjoin(A, B, on=:b).c) == ["b", "a"]
    @test levels(innerjoin(B, A, on=:b).c) == ["b", "a"]
    @test levels(leftjoin(A, B, on=:b).c) == ["b", "a"]
    @test levels(outerjoin(A, B, on=:b).c) == ["b", "a"]
    @test levels(semijoin(B, A, on=:b).c) == ["b", "a"]

    dsl = Dataset(x = categorical(["c","d",missing, "e","c"]), y = 1:5)
    dsr = Dataset(x = categorical(["a", "f", "e", "c"]), z = PooledArray([22,missing,33,44]))
    ds_left = leftjoin(dsl, dsr, on = :x)
    ds_left_t = Dataset([categorical(["c", "d", missing, "e", "c"]),
                 Union{Missing, Int64}[1, 2, 3, 4, 5],
                 Union{Missing, Int64}[44, missing, missing, 33, 44]],[:x, :y, :z])
    @test ds_left == ds_left_t
    ds_left = leftjoin(dsr, dsl, on = :x)
    ds_left_t = Dataset([categorical(["a", "f", "e", "c", "c"]),
                 Union{Missing, Int64}[22, missing, 33, 44, 44],
                 Union{Missing, Int64}[missing, missing, 4, 1, 5]],[:x, :z, :y])
    ds_inner = innerjoin(dsl, dsr, on = :x)
    ds_inner_t = Dataset([categorical(["c", "e", "c"]),
                 Union{Missing, Int64}[1, 4, 5],
                 Union{Missing, Int64}[44, 33, 44]], [:x, :y, :z])
    @test ds_inner == ds_inner_t
    for i in 1:20 # when we fix the issue with Threads we can make sure it is ok
        ds_outer = outerjoin(dsl, dsr, on = :x)
        ds_outer_t = Dataset([categorical(["c", "d", missing, "e", "c", "a", "f"]),
                 Union{Missing, Int64}[1, 2, 3, 4, 5, missing, missing],
                 Union{Missing, Int64}[44, missing, missing, 33, 44, 22, missing]], [:x, :y, :z])
        @test ds_outer == ds_outer_t
    end
    dsl = Dataset(x = categorical(["c","d",missing, "e","c"]), y = 1:5)
    dsr = Dataset(x = categorical(["a", "f", "e", "c"]), z = PooledArray([2,missing,3,4]))
    for i in 1:20
        ds_left = leftjoin(dsl, dsr, on = [:y=>:z], makeunique=true)
        ds_left_t = Dataset([categorical(["c", "d", missing, "e", "c"]),
                     Union{Missing, Int64}[1, 2, 3, 4, 5],
                     categorical([missing, "a", "e", "c", missing])],[:x, :y, :x_1])
        @test ds_left == ds_left_t
        ds_outer = outerjoin(dsl, dsr, on = [:y=>:z], makeunique=true)
        ds_outer_t = Dataset([ categorical(["c", "d", missing, "e", "c", missing]),
                     Union{Missing, Int64}[1, 2, 3, 4, 5, missing],
                     categorical([missing, "a", "e", "c", missing, "f"])], [:x, :y, :x_1])
        @test ds_outer == ds_outer_t
    end
    dsl = Dataset(x = categorical(["c","d",missing, "e","c"]), y = PooledArray(1:5))
    dsr = Dataset(x = categorical(["a", "f", "e", "c"]), z = PooledArray([2,missing,3,4]))
    for i in 1:20
        ds_left = leftjoin(dsl, dsr, on = [:y=>:z], makeunique=true)
        ds_left_t = Dataset([categorical(["c", "d", missing, "e", "c"]),
                     Union{Missing, Int64}[1, 2, 3, 4, 5],
                    categorical([missing, "a", "e", "c", missing])],[:x, :y, :x_1])
        @test ds_left == ds_left_t
        ds_outer = outerjoin(dsl, dsr, on = [:y=>:z], makeunique=true)
        ds_outer_t = Dataset([ categorical(["c", "d", missing, "e", "c", missing]),
                     Union{Missing, Int64}[1, 2, 3, 4, 5, missing],
                     categorical([missing, "a", "e", "c", missing, "f"])], [:x, :y, :x_1])
        @test ds_outer == ds_outer_t
    end
    dsl = Dataset(x = categorical(["c","d",missing, "e","c"]), y = PooledArray(1:5))
    dsr = Dataset(x = categorical(["a", "f", "e", "c"]), z = [2,missing,3,4])
    for i in 1:20
        ds_left = leftjoin(dsl, dsr, on = [:y=>:z], makeunique=true)
        ds_left_t = Dataset([categorical(["c", "d", missing, "e", "c"]),
                     [1, 2, 3, 4, 5],
                     categorical([missing, "a", "e", "c", missing])],[:x, :y, :x_1])
        @test ds_left == ds_left_t
        ds_outer = outerjoin(dsl, dsr, on = [:y=>:z], makeunique=true)
        ds_outer_t = Dataset([categorical(["c", "d", missing, "e", "c", missing]),
                     Union{Missing, Int64}[1, 2, 3, 4, 5, missing],
                     categorical([missing, "a", "e", "c", missing, "f"])], [:x, :y, :x_1])
        @test ds_outer == ds_outer_t
    end

    dsl = Dataset(x = PooledArray([1, 7, 19, missing]), y = 1:4)
    dsr = Dataset(x = [missing,5, 19, 1], z = ["a", "b", "c", "d"])
    for i in 1:20
        res = contains(dsl, dsr, on = :x)
        @test res == Bool[1,0,1,1]
    end
    for i in 1:20
        res = contains(dsr, dsl, on = :x)
        @test res == Bool[1,0,1,1]
    end
    dsl = Dataset(x = PooledArray([1, 7, 19, missing]), y = 1:4)
    dsr = Dataset(x = categorical([missing,5, 19, 1]), z = ["a", "b", "c", "d"])
    for i in 1:20
        res = contains(dsl, dsr, on = :x)
        @test res == Bool[1,0,1,1]
    end
    for i in 1:20
        res = contains(dsr, dsl, on = :x)
        @test res == Bool[1,0,1,1]
    end
    dsl = Dataset(x = categorical([1, 7, 19, missing]), y = 1:4)
    dsr = Dataset(x = categorical([missing,5, 19, 1]), z = ["a", "b", "c", "d"])
    for i in 1:20
        res = contains(dsl, dsr, on = :x)
        @test res == Bool[1,0,1,1]
    end
    for i in 1:20
        res = contains(dsr, dsl, on = :x)
        @test res == Bool[1,0,1,1]
    end

end



@testset "joins with categorical columns and no matching rows - from DataFrames test sets" begin
    l = Dataset(a=1:3, b=categorical(["a", "b", "c"]))
    r = Dataset(a=4:5, b=categorical(["d", "e"]))
    nl = size(l, 1)
    nr = size(r, 1)

    CS = eltype(l.b.val)

    # joins by a and b
    @test innerjoin(l, r, on=[:a, :b]) == Dataset(a=Int[], b=similar(l.a.val, 0))
    @test eltype.(eachcol(innerjoin(l, r, on=[:a, :b]))) == [Union{Missing, Int}, CS]

    @test leftjoin(l, r, on=[:a, :b]) == Dataset(a=l.a.val, b=l.b.val)
    @test eltype.(eachcol(leftjoin(l, r, on=[:a, :b]))) == [Union{Int, Missing}, CS]

    @test outerjoin(l, r, on=[:a, :b]) ==
        Dataset(a=vcat(l.a.val, r.a.val), b=vcat(l.b.val, r.b.val))
    @test eltype.(eachcol(outerjoin(l, r, on=[:a, :b]))) == [Union{Int, Missing}, CS]

    # joins by a
    @test innerjoin(l, r, on=:a, makeunique=true) ==
        Dataset(a=Int[], b=similar(l.b.val, 0), b_1=similar(r.b.val, 0))
    @test eltype.(eachcol(innerjoin(l, r, on=:a, makeunique=true))) == [Union{Missing, Int}, CS, CS]

    @test leftjoin(l, r, on=:a, makeunique=true) ==
        Dataset(a=l.a.val, b=l.b.val, b_1=similar(r.b.val, nl))
    @test eltype.(eachcol(leftjoin(l, r, on=:a, makeunique=true))) ==
        [Union{Missing, Int}, CS, Union{CS, Missing}]

    @test outerjoin(l, r, on=:a, makeunique=true) ==
        Dataset(a=vcat(l.a.val, r.a.val),
                  b=vcat(l.b.val, fill(missing, nr)),
                  b_1=vcat(fill(missing, nl), r.b.val))
    @test eltype.(eachcol(outerjoin(l, r, on=:a, makeunique=true))) ==
        [Union{Missing, Int}, Union{CS, Missing}, Union{CS, Missing}]

    # joins by b
    @test innerjoin(l, r, on=:b, makeunique=true) ==
        Dataset(a=Int[], b=similar(l.b.val, 0), a_1=similar(r.b.val, 0))
    @test eltype.(eachcol(innerjoin(l, r, on=:b, makeunique=true))) == [Union{Missing, Int}, CS, Union{Missing, Int}]

    @test leftjoin(l, r, on=:b, makeunique=true) ==
        Dataset(a=l.a.val, b=l.b.val, a_1=fill(missing, nl))
    @test eltype.(eachcol(leftjoin(l, r, on=:b, makeunique=true))) ==
        [Union{Missing, Int}, CS, Union{Int, Missing}]

    @test outerjoin(l, r, on=:b, makeunique=true) ==
        Dataset(a=vcat(l.a.val, fill(missing, nr)),
                  b=vcat(l.b.val, r.b.val),
                  a_1=vcat(fill(missing, nl), r.a.val))
    @test eltype.(eachcol(outerjoin(l, r, on=:b, makeunique=true))) ==
        [Union{Int, Missing}, CS, Union{Int, Missing}]

    dsl = Dataset(x= categorical([1,2,1]))
    dsr = Dataset(x=1:5)
    # categorical values cannot be compared to non categorical values
    @test_throws TaskFailedException leftjoin(dsl, dsr, on =:x)
end
