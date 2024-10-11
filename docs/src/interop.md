# Interoperability with other languages

These example show how JMPReader.jl could be used from other languages.

## R

```r
install.packages("JuliaCall")
library(JuliaCall)
julia_setup(installJulia = TRUE)
julia_install_package_if_needed("JMPReader")
julia_library("JMPReader")
df <- julia_call("readjmp", "example1.jmp")
```

## Python

With `juliacall` and `pandas` installed

```python
from juliacall import Main as jl
jl.seval("using JMPReader")
df = jl.readjmp("example1.jmp")
pt = jl.pytable(df, "pandas")
```