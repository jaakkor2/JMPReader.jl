# JMPReader.jl

Reader for JMP data tables.

Many data types are likely not yet implemented.  Please file an issue with a minimal example file that can be included in the tests.  PRs welcome.

## Example
```
using JMPReader
fn = joinpath(pathof(JMPReader), "..", "..", "test", "example1.jmp")
df = readjmp(fn)
```
outputs
```
4×12 DataFrame
 Row │ ints      floats    charconstwidth  time                 date        duration              charconstwidth2  charvariable16                     formula  pressures      char utf8  charvariable8 
     │ Float64?  Float64?  String          DateTime?            Date?       Millisec…             String           String                             String   Float64?       String     String        
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │      1.0      11.1  a               1976-04-01T21:12:00  2024-01-13  2322000 milliseconds  a                aa                                 2            101.325    ꙮꙮꙮ        a
   2 │      2.0      22.2  b               1984-08-06T23:58:00  2024-01-14  364000 milliseconds   bb               bbbb                               4        missing        🚴💨       bb
   3 │      3.0      33.3  c               2003-06-02T17:00:00  missing     229000 milliseconds   ccc              cccccccc                           6              2.6      jäääär     cc
   4 │      4.0      44.4  d               missing              2032-02-12  0 milliseconds        dddd             abcdefghijabcdefghijabcdefghijab…  8              4.6e113  辛口       abcdefghijkl
```
### See also

* [SASLib.jl](https://github.com/tk3369/SASLib.jl) is a fast reader for sas7bdat files.