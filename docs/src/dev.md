## Testing

Basic testing with limited number of files
```julia
using Pkg
Pkg.test("JMPReader")
```

Utility function `JMPReader.scandir` is provided that scans recursively the argument directory.
For example,
```julia
JMPReader.scandir(joinpath(pathof(JMPReader), "..", "..", "test"))
```
reads 12 JMP-files,
```julia
JMPReader.scandir(raw"C:\Program Files\SAS\JMPPRO\17\Samples\Data")
```
reads successfully 605 JMP-files, and
```julia
JMPReader.scandir(raw"C:\Program Files\JMP\JMPPRO\18\Samples\Data")
```
reads successfully 612 JMP-files.

## Looking into the binary .jmp file

### Finding strings

Location of strings in the binary `.jmp` can be found using a snippet like
```julia
fn = joinpath(pathof(JMPReader), "..", "..", "test", "example1.jmp")
raw = read(fn)
seq = reinterpret(UInt8, codeunits("jäääär"))
findall(seq, raw)
```
returns
```
1-element Vector{UnitRange{Int64}}:
 1986:1995
```

Hex editor can be useful, for example [Hex Editor for VS Code](https://github.com/microsoft/vscode-hexeditor).

If string is not found, columns could be GZ compressed.  In that case, see options in JMP File->Preferences.

### Reading columns

This snippet reads the fourth column

```julia
fn = joinpath(pathof(JMPReader), "..", "..", "test", "example1.jmp")
io = open(fn)
info = JMPReader.metadata(io)
d = JMPReader.column_data(io, info, 4, Vector{UInt8}())
close(io)
```
