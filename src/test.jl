# functions to help testing (or than standard testing in test-directory)

"""
    scandir(dir)

Scan directory `dir` for .jmp files and read them.

# Examples
```
    JMPReader.scandir(raw"C:\\Program Files\\SAS\\JMP\\17\\Samples\\Data")
    JMPReader.scandir(joinpath(pathof(JMPReader), "..", "..", "test"))
```
"""
function scandir(dir)
    isdir(dir) || throw(ErrorException("$dir is not a directory"))
    n = 0
    for (root, dirs, files) in walkdir(dir)
        for file in files
            endswith(file, ".jmp") || continue
            fn = normpath(joinpath(root, file))
            @show fn
            readjmp(fn)
            n += 1
        end
    end
    @info "Read $n JMP-files."
    nothing
end