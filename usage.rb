require_relative 'options'

Options.help do |h|
    h.name     = "blossom"
    h.commands = ["--help", "-h"]
    h.header   = "Blossom usage:"
    h.footer   = "See https://github.com/blossom-lang/blossom for any major issues."
end

Options.positional do |p|
    p.name        = :program_file
    p.type        = "FILE"
    p.required    = true
    p.description = "The file path to the blossom program."
    p.hint        = "path/to/program.blsm"
end

Options.group do |g|
    g.name     = :graph_input
    g.required = true
    g.options  = [
        Options.positional do |p|
            p.type        = "STRING"
            p.description = "The text of the blossom graph."
            p.hint        = "graph_text"
        end,
        Options.value do |v|
            v.prefixes    = ["--input", "-i"]
            v.types       = ["FILE"]
            v.description = "The file path to the blossom graph."
            v.hint        = "path/to/graph.blsm"
        end,
    ]
end

Options.value do |v|
    v.name        = :output_file
    v.types       = ["FILE"]
    v.required    = false
    v.default     = nil
    v.prefixes    = ["--output", "-o"]
    v.description = "The file path to save the resultant graph of the program."
    v.hints       = ["path/to/output/graph.blsm"]
end

Options.flag do |f|
    f.name        = :verbose
    f.required    = false
    f.default     = false
    f.commands    = ["--verbose"]
    f.switch      = "v"
    f.description = "Prints information about the running process."
end

Options.flag do |f|
    f.name        = :tracing
    f.required    = false
    f.default     = false
    f.commands    = ["--trace"]
    f.switch      = "t"
    f.description = "Outputs intermediate graphs throughout the program's execution."
end

Options.value do |v|
    v.name        = :trace_dir
    v.types       = ["DIR"]
    v.required    = false
    v.default     = "trace"
    v.prefixes    = ["--trace-directory"]
    v.description = "The directory to save the intermediate graphs."
    v.hints       = ["directory/to/save/trace/"]
end

Options.group do |g|
    g.name     = :colour_strategy
    g.required = false
    g.default  = :ignore
    g.options  = [
        Options.flag do |f|
            f.value       = :ignore
            f.commands    = ["--ignore-colours"]
            f.description = ""
        end,
        Options.flag do |f|
            f.value       = :merge
            f.commands    = ["--merge-colours"]
            f.description = ""
        end,
    ]
end

Options.flag do |f|
    f.name        = :keep_rationals
    f.required    = false
    f.default     = false
    f.commands    = ["--keep-rationals"]
    f.description = "Maintains fractional values instead of converting to floats."
end

Options.group do |g|
    g.name     = :output_type
    g.required = false
    g.default  = :blossom
    g.options  = [
        Options.flag do |f|
            f.value       = :dot
            f.commands    = ["--dot"]
            f.description = "Saves output graphs in the Dot format. See https://www.graphviz.org/doc/info/lang.html"
        end,
        Options.flag do |f|
            f.value       = :graphML
            f.commands    = ["--graphML"]
            f.description = "Saves output graphs in the GraphML format. See http://graphml.graphdrawing.org/"
        end,
        Options.flag do |f|
            f.value       = :blossom
            f.commands    = ["--blossom"]
            f.description = "Saves output graphs in the Blossom format."
        end,
    ]
end

Options.flag do |f|
    f.name        = :validate_only
    f.required    = false
    f.default     = false
    f.commands    = ["--validate", "--dry-run"]
    f.description = "Parses the program, and any graphs, but does not execute it."
end

Options.flag do |f|
    f.name        = :version
    f.required    = false
    f.default     = false
    f.commands    = ["--version"]
    f.switch      = "V"
    f.description = "Prints the version of this blossom interpreter."
end
