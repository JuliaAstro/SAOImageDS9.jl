# Changes in DS9.jl package

## Version 0.2.0

- Use the per-thread persistent client connection now provided by `XPA.jl`.
  As a result, `DS9.connection()` is just `XPA.connection()`.
