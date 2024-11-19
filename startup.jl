using OhMyREPL
OhMyREPL.enable_autocomplete_brackets(false)
# ENV["JULIA_REVISE"] = "manual"
# - Use Revise Package
try
    using Revise
catch e
    @warn "Error initializing Revise" exception = (e, catch_backtrace())
end

using BenchmarkTools

module PlutoStarter

DEFAULT_PLUTO_PORT = 1234
export @run_pluto, @run_pluto_local, @run_pluto_server

function _run_pluto(args...; kwargs...)
    # We have to track the port in order to serve a Remote REPL at 10 ports above the Pluto server one
    port = DEFAULT_PLUTO_PORT
    # Parse the args and transform them in kwargs
    foreach(args) do arg
        @assert Meta.isexpr(arg, :(=)) "Only arguments of the type name=value are supported by the macro"
        arg.args[1] == :port && (port = arg.args[2])
        # Change the head into kw
        arg.head = :kw
    end
    default_kwargs = [Expr(:kw, k, v) for (k, v) in kwargs]
    block = quote
        import Pluto
        # import RemoteREPL
        # # We start a RemoteREPL server with port number 10 ports above the Pluto server
        # @async RemoteREPL.serve_repl($port + 10)
        # We create the options to run pluto
        local options = Pluto.Configuration.from_flat_kwargs(;)
    end
    options_expr = block.args[end].args[1].args[2]
    default_kwargs = Expr(:(...), Expr(:tuple, Expr(:parameters, default_kwargs...)))
    push!(options_expr.args[end].args, default_kwargs)
    parsed_kwargs = Expr(:(...), Expr(:tuple, Expr(:parameters, args...)))
    push!(options_expr.args[end].args, parsed_kwargs)
    # Now we create the session in a variable called pluto_session and then run it
    push!(block.args, :(pluto_session = Pluto.ServerSession(; options)))
    push!(block.args, :(Pluto.run(pluto_session)))
    esc(block)
end
macro run_pluto_server(args...)
    kwargs = (; auto_reload_from_file=true, auto_reload_from_file_ignore_pkg=true, host="0.0.0.0", port=DEFAULT_PLUTO_PORT, launch_browser=false)
    _run_pluto(args...; kwargs...)
end
macro run_pluto_local(args...)
    kwargs = (; auto_reload_from_file=true, auto_reload_from_file_ignore_pkg=true, require_secret_for_access=false, port=DEFAULT_PLUTO_PORT, require_secret_for_open_links=false, launch_browser=false, workspace_use_distributed_stdlib=false)
    _run_pluto(args...; kwargs...)
end
var"@run_pluto" = var"@run_pluto_local"
end
using .PlutoStarter

# using ESAGitlabTemplates
# esagitlab_template = ESAGitlabTemplate(;
# 	user = "AlbertoMengali",
# 	email = "Alberto.Mengali@esa.int",
# 	authors = "Alberto Mengali <alberto.mengali@esa.int>",
# 	dir = "$(homedir())/Repos/gitlab_esa",
# )


macro testenv()
    quote
        using TestEnv
        TestEnv.activate()
    end |> esc
end

# Add a temp env to the load path
push!(LOAD_PATH, mktempdir(;prefix = "startup_env_"))

if isinteractive()
    import BasicAutoloads
    BasicAutoloads.register_autoloads([
        ["@b", "@be"] => :(using Chairmarks),
        ["@benchmark"] => :(using BenchmarkTools),
        ["@test", "@testset", "@test_broken", "@test_deprecated", "@test_logs",
            "@test_nowarn", "@test_skip", "@test_throws", "@test_warn", "@inferred"] =>
            :(using Test),
    ])
end