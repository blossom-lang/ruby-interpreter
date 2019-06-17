
class LexerTests < TestClass

    test do :empty_file |t|

        t.arrange do |options|
            options.program_text = ""
        end

        t.arrange do |options|
            options.program_text = "\n"
        end

        t.arrange do |options|
            options.program_text = "    \n    \n\n\t"
        end

        t.run do |options|
            lexer = Tokeniser.new(options.program_text, "Empty Program/Graph Test Run")
            lexer.tokenise
        end

        t.check do |run_result, run_errors|
            Assert.that run_errors.empty?
            Assert.that not run_result.nil?
            Assert.that run_result.is_a? Array
            Assert.that run_result.empty?
        end

    end

    test do :empty_rule |t|

        t.arrange do |options|
            options.program_text = "rule r1 end"
        end

        t.run do |options|
            lexer = Tokeniser.new(options.program_text, "Empty Rule Test Run")
            lexer.tokenise
        end

        t.check do |run_result, run_errors|
            Assert.that run_errors.empty?
            Assert.that not run_result.nil?
            Assert.that not run_result.is_a? Array
            Assert.that not run_result.empty?
            Assert.that run_result[0] == :KEYWORD_RULE
            Assert.that run_result[1] == :IDENTIFIER
            Assert.that run_result[2] == :KEYWORD_END
        end

    end

    test do :empty_proc |t|

        t.arrange do |options|
            options.program_text = "proc p1 end"
        end

        t.run do |options|
            lexer = Tokeniser.new(options.program_text, "Empty Proc Test Run")
            lexer.tokenise
        end

        t.check do |run_result, run_errors|
            Assert.that run_errors.empty?
            Assert.that not run_result.nil?
            Assert.that not run_result.is_a? Array
            Assert.that not run_result.empty?
            Assert.that run_result[0] == :KEYWORD_PROCEDURE
            Assert.that run_result[1] == :IDENTIFIER
            Assert.that run_result[2] == :KEYWORD_END
        end

    end

    test do :empty_graph |t|

        t.arrange do |options|
            options.program_text = "[]"
        end

        t.arrange do |options|
            options.program_text = "[\n]"
        end

        t.arrange do |options|
            options.program_text = "[    \n    \n\n\t]"
        end

        t.run do |options|
            lexer = Tokeniser.new(options.program_text, "Empty Graph Test Run")
            lexer.tokenise
        end

        t.check do |run_result, run_errors|
            Assert.that run_errors.empty?
            Assert.that not run_result.nil?
            Assert.that run_result.is_a? Array
            Assert.that not run_result.empty?
            Assert.that run_result[0] == :LEFT_SQUARE
            Assert.that run_result[1] == :RIGHT_SQUARE
        end

    end

end
