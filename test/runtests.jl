using Test
using JMPReader
using Dates: Date, DateTime, Second
using Printf: @sprintf

@testset "example1.jmp" begin
    df = readjmp(joinpath(@__DIR__, "example1.jmp"))
    @test df.ints == [1.0,2.0,3.0,4.0]
    @test df.floats == [11.1,22.2,33.3,44.4]
    @test df.charconstwidth == ["a","b","c","d"]
    @test df.time[[1,2,3]] == [DateTime(1976,4,1,21,12), DateTime(1984,8,6,23,58), DateTime(2003,6,2,17)]
    @test ismissing(df.time[4])
    @test df.date[[1,2,4]] == [Date(2024,1,13), Date(2024,1,14), Date(2032,2,12)]
    @test ismissing(df.date[3])
    @test df.duration == [Second(2322), Second(364), Second(229), Second(0)]
    @test df.charconstwidth2 == ["a","bb","ccc","dddd"]
    @test df.charvariable16 == ["aa","bbbb","cccccccc","abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij"]
    @test df.formula == ["2","4","6","8"]
    @test df.pressures[[1,3,4]] == [101.325,2.6,4.63309e110]
    @test ismissing(df.pressures[2])
    @test df."char utf8" == ["ꙮꙮꙮ","🚴💨","jäääär","辛口"]
    @test df.charvariable8 == ["a","bb","cc","abcdefghijkl"]
end

@testset "compressed.jmp" begin
    df = readjmp(joinpath(@__DIR__, "compressed.jmp"))
    @test all(df.numeric .== 1)
    @test all(df.character1 .== "a")
    @test all(df.character11 .== "abcdefghijk")
    @test all(df.character130 .== "abcdefghij"^13)
    @test all(df."y-m-d h:m:s" .== DateTime(1904, 1, 1, 0, 0, 1))
    @test all(df."yyyy-mm-dd" .== DateTime(2024, 1, 20))
    @test all(df."min:s" .== Second(196))
end

@testset "date.jmp" begin
    df = readjmp(joinpath(@__DIR__, "date.jmp"))
    @test df.ddmmyyyy == [Date(2011,5,25), Date(1973,5,24), Date(2027,5,22), Date(2020,5,1)]
end

@testset "duration.jmp" begin
    df = readjmp(joinpath(@__DIR__, "duration.jmp"))
    @test df.":day:hr:m:s" == fill(Second(88201), 3)
end

@testset "time.jmp" begin
    df = readjmp(joinpath(@__DIR__, "time.jmp"))
    @test Matrix(df) == repeat([DateTime(1914,4,27,19,54,14), DateTime(1978,1,7,6,11,24)], 1, 20)
end

@testset "longcolumnnames.jmp" begin
    df = readjmp(joinpath(@__DIR__, "longcolumnnames.jmp"))
    name1 = prod([@sprintf("%010d", i) for i in 1:140])
    name2 = prod([@sprintf("%010d", i) for i in 1:280])
    @test names(df) == [name1, name2]
    @test Matrix(df) == [1 2; 1 2; 1 2]
end

@testset "singlecolumnsinglerow.jmp" begin
    df = readjmp(joinpath(@__DIR__, "singlecolumnsinglerow.jmp"))
    @test size(df) == (1, 1)
    @test df."Column 1" == [1]
end

@testset "column name filtering" begin
    names = ["foo", "foo_x", "foo_y", "bar", "bar_x", "bar_y", "baz"]
    @test JMPReader.filter_columns(names, [1,8], nothing) == [1]
    @test JMPReader.filter_columns(names, [1,7,"bar"], nothing) == [1,4,7]
    @test JMPReader.filter_columns(names, [1,7,"bar",4], nothing) == [1,4,7]
    @test JMPReader.filter_columns(names, nothing, [r"^foo"]) == [4,5,6,7]
    @test JMPReader.filter_columns(names, nothing, [r"_x$", :bar]) == [1,3,6,7]
    @test JMPReader.filter_columns(names, [3:10], [10:-3:1]) == [3,5,6]
    @test JMPReader.filter_columns(names, ["foo_x", :baz, r"^bar", 3, 1:2], [4, r"x$"]) == [1,3,6,7]
end