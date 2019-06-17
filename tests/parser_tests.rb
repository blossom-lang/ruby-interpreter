
class ParserTests < TestClass

    def self.get_tokens(text)
        lexer = Lexer.new(text, "Parser Test Run")
        return lexer.tokenise
    end

    test do :missing_graph |t|

        t.arrange do |options|
            options.graph_tokens = []
        end

        t.arrange do |options|
            graph_text = ""
            options.graph_tokens = get_tokens(graph_text)
        end

        t.arrange do |options|
            graph_text = "\n"
            options.graph_tokens = get_tokens(graph_text)
        end

        t.arrange do |options|
            graph_text = "  \n \n \t   \n\n\t"
            options.graph_tokens = get_tokens(graph_text)
        end

        t.run do |options|
            parser = Parser.new(options.graph_tokens)
            parser.parse_graph
        end

        t.check do |run_result, run_errors|
            Assert.that not run_errors.empty?
            Assert.that run_result.nil?
            p run_errors
        end

    end

    test do :empty_graph |t|

        t.arrange do |options|
            graph_text = "[]"
            options.graph_tokens = get_tokens(graph_text)
        end

        t.arrange do |options|
            graph_text = "[\n]"
            options.graph_tokens = get_tokens(graph_text)
        end

        t.arrange do |options|
            graph_text = "[    \n   \t\n\n ]"
            options.graph_tokens = get_tokens(graph_text)
        end

        t.run do |options|
            parser = Parser.new(options.graph_tokens)
            parser.parse_graph
        end

        t.check do |run_result, run_errors|
            Assert.that run_errors.empty?
            Assert.that not run_result.nil?
            p run_result
        end

    end

    test do :empty_program |t|

        t.arrange do |options|
            program_text = ""
            options.program_tokens = get_tokens(program_text)
        end

        t.arrange do |options|
            program_text = "\n"
            options.program_tokens = get_tokens(program_text)
        end

        t.arrange do |options|
            program_text = "\n \t \n    \t"
            options.program_tokens = get_tokens(program_text)
        end

        t.run do |options|
            parser = Parser.new(options.program_tokens)
            parser.parse_program
        end

        t.check do |run_result, run_errors|
            Assert.that run_errors.empty?
            Assert.that not run_result.nil?
            p run_result
        end

    end

end