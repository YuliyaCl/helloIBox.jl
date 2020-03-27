using Clang
using Clang.LibClang.LLVM_jll

# HIGHS_DIR = "test/dll_test-master/Dll_test"
# const header_file = joinpath(HIGHS_DIR, "DLL_test.h")

HIGHS_DIR = "Y:/Yuly/ibjuly"
const header_file = joinpath(HIGHS_DIR, "ibjuly.h")
const LIB_HEADERS = [header_file]

const ctx = Clang.DefaultContext()

Clang.parse_headers!(ctx, LIB_HEADERS,
    includes=[Clang.CLANG_INCLUDE],
)

ctx.libname = "ibjuly"
ctx.options["is_function_strictly_typed"] = true
ctx.options["is_struct_mutable"] = false

const api_file = joinpath(@__DIR__, "../src/wrapper", "$(ctx.libname)_api.jl")
api_file = joinpath(@__DIR__, "ibjuly_api.jl")
api_stream = open(api_file, "w")

for trans_unit in ctx.trans_units
    root_cursor = getcursor(trans_unit)
    push!(ctx.cursor_stack, root_cursor)
    header = spelling(root_cursor)
    @info "wrapping header: $header ..."
    # loop over all of the child cursors and wrap them, if appropriate.
    ctx.children = children(root_cursor)
    for (i, child) in enumerate(ctx.children)
        child_name = name(child)
        child_header = filename(child)
        ctx.children_index = i
        # choose which cursor to wrap
        startswith(child_name, "__") && continue  # skip compiler definitions
        child_name in keys(ctx.common_buffer) && continue  # already wrapped
        child_header != header && continue  # skip if cursor filename is not in the headers to be wrapped

        wrap!(ctx, child)
    end
    @info "writing $(api_file)"
    println(api_stream, "# Julia wrapper for header: $(basename(header))")
    println(api_stream, "# Automatically generated using Clang.jl\n")
    print_buffer(api_stream, ctx.api_buffer)
    empty!(ctx.api_buffer)  # clean up api_buffer for the next header
end
close(api_stream)

# write "common" definitions: types, typealiases, etc.
common_file = joinpath(@__DIR__, "ibjuly_common.jl")
open(common_file, "w") do f
    println(f, "# Automatically generated using Clang.jl\n")
    print_buffer(f, dump_to_buffer(ctx.common_buffer))
end
