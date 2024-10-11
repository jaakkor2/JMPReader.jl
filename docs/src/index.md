```@meta
CurrentModule = JMPReader
```

# JMPReader

Documentation for [JMPReader](https://github.com/jaakkor2/JMPReader.jl).

[JMP](https://en.wikipedia.org/wiki/JMP_(statistical_software)) is commercial statistical software.  This package provides an independent reader for `.jmp` files
implemented in Julia.

## Basic usage

Basic usage is
```
using JMPReader
fn = joinpath(pathof(JMPReader), "..", "..", "test", "example1.jmp")
df = readjmp(fn)
```
to read file `fn` and get the data as a Julia `DataFrame`.  All columns are included
```
4×12 DataFrame
 Row │ ints  floats   charconstwidth  time                 date        duration              charconstwidth2  charvariable16                     formula  pressures          char utf8  charvariable8
     │ Int8  Float64  String          DateTime?            Date?       Millisec…             String           String                             String   Float64?           String     String
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │    1     11.1  a               1976-04-01T21:12:00  2024-01-13  2322000 milliseconds  a                aa                                 2            101.325        ꙮꙮꙮ        a
   2 │    2     22.2  b               1984-08-06T23:58:00  2024-01-14  364000 milliseconds   bb               bbbb                               4        missing            🚴💨       bb
   3 │    3     33.3  c               2003-06-02T17:00:00  missing     229000 milliseconds   ccc              cccccccc                           6              2.6          jäääär     cc
   4 │    4     44.4  d               missing              2032-02-12  0 milliseconds        dddd             abcdefghijabcdefghijabcdefghijab…  8              4.63309e110  辛口       abcdefghijkl
```

## Choosing columns

Two keyword arguments are available, `include_columns` and `exclude_columns`
```
df = readjmp(fn, include_columns=[2, "date", r"^char"], exclude_columns=[r"varia"])
``` 
returns the second column `floats`, a column named `date`, columns that start with `char`,
but excluding columns whose name contain a string `varia`.
```
4×5 DataFrame
 Row │ floats   charconstwidth  date        charconstwidth2  char utf8
     │ Float64  String          Date?       String           String
─────┼─────────────────────────────────────────────────────────────────
   1 │    11.1  a               2024-01-13  a                ꙮꙮꙮ
   2 │    22.2  b               2024-01-14  bb               🚴💨
   3 │    33.3  c               missing     ccc              jäääär
   4 │    44.4  d               2032-02-12  dddd             辛口
```
