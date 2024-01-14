using Test
using JMPReader
using Dates: Date, DateTime, Second

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
    @test df.pressures[[1,3,4]] == [101.325,2.6,4.6e113]
    @test ismissing(df.pressures[2])
    @test df."char utf8" == ["ꙮꙮꙮ","🚴💨","jäääär","辛口"]
    @test df.charvariable8 == ["a","bb","cc","abcdefghijkl"]
end