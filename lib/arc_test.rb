require 'date'
require 'ostruct'

module ConsoleStyle

    # From here:
    # http://pueblo.sourceforge.net/doc/manual/ansi_color_codes.html

    RESET             = "\33[0m"  # reset; clears all colors and styles (to white on black)

    BOLD_ON           = "\33[1m"  # bold on (see below)
    ITALICS_ON        = "\33[3m"  # italics on
    UNDERLINE_ON      = "\33[4m"  # underline on
    INVERSE_ON        = "\33[7m"  # switch foreground and background colour
    STRIKETHROUGH_ON  = "\33[9m"  # strikethrough on
    BOLD_OFF          = "\33[22m" # bold off (see below)
    ITALICS_OFF       = "\33[23m" # italics off
    UNDERLINE_OFF     = "\33[24m" # underline off
    INVERSE_OFF       = "\33[27m" # inverse off
    STRIKETHROUGH_OFF = "\33[29m" # strikethrough off
    
    FG_BLACK   = "\33[30m" # set foreground color to black
    FG_RED     = "\33[31m" # set foreground color to red
    FG_GREEN   = "\33[32m" # set foreground color to green
    FG_YELLOW  = "\33[33m" # set foreground color to yellow
    FG_BLUE    = "\33[34m" # set foreground color to blue
    FG_MAGENTA = "\33[35m" # set foreground color to magenta (purple)
    FG_CYAN    = "\33[36m" # set foreground color to cyan
    FG_WHITE   = "\33[37m" # set foreground color to white
    FG_DEFAULT = "\33[39m" # set foreground color to default (white)

    BG_BLACK   = "\33[40m" # set background color to black
    BG_RED     = "\33[41m" # set background color to red
    BG_GREEN   = "\33[42m" # set background color to green
    BG_YELLOW  = "\33[43m" # set background color to yellow
    BG_BLUE    = "\33[44m" # set background color to blue
    BG_MAGENTA = "\33[45m" # set background color to magenta (purple)
    BG_CYAN    = "\33[46m" # set background color to cyan
    BG_WHITE   = "\33[47m" # set background color to white
    BG_DEFAULT = "\33[49m" # set background color to default (black)

end

class TestInstance

    attr_reader :name
    attr_reader :cases
    attr_reader :run_block
    attr_reader :check_block

    def initialize(name)
        @name = name
        @cases = []
        @run_block   = nil
        @check_block = nil
    end

    def arrange(&block)
        @cases.push(block)
    end

    def run(&block)
        @run_block = block
    end

    def check(&block)
        @check_block = block
    end

end

class FailedAssertionError < StandardError
end

class Assert

    def self.that(condition)
        if !condition
            # TODO: get text of assertion and present it with error message
            raise FailedAssertionError.new("Assertion Failed")
        end
    end

end

class TestRun

    INVALID = TestRun.new

    attr_reader :start_time
    attr_reader :thread

    def initialize(test_instance, test_case_index, result_object)
        @test = test_instance
        @test_case = @test.cases[test_case_index]
        # TODO: get more origin information if it can't be deduced later
        @start_time = nil
        @end_time   = nil
        @result = nil
        @test_result = result_object
        @thread = nil
    end

    def started?
        return !@start_time.nil?
    end

    def finished?
        return !@end_time.nil?
    end

    def run
        return if finished?
        @thread = Thread.new do

            arrange_errors = []
            run_errors     = []
            check_errors   = []
            @start_time    = DateTime.now
            test_success   = true
            run_success    = false
            settings       = OpenStruct.new

            # Arrange
            begin
                @test_case.call(settings)
            rescue StandardError => e
                arrange_errors.push(e)
                test_success = false
            end

            # Run
            begin
                run_result_value = @test.run_block.call(settings)
                run_success = true
            rescue StandardError => e
                run_errors.push(e)
            end
            end_time = DateTime.now

            run_result = OpenStruct.new
            run_result.success    = run_success
            run_result.value      = run_success ? run_result_value : nil
            run_result.errors     = run_success ? [] : run_errors

            # Check
            begin
                @test.check_block.call(run_result.value, run_result.errors)
            rescue StandardError => e
                check_errors.push(e)
                test_success = false
            end

            @test_result.test       = @test
            @test_result.success    = test_success
            @test_result.start_time = @start_time
            @test_result.end_time   = end_time
            @test_result.errors     = arrange_errors
            @test_result.failures   = check_errors

            @end_time = end_time
        end
        @thread.abort_on_exception = true
    end

    def result
        if self == INVALID
            return nil
        end
        if !finished?
            @thread.join
        end
        return @test_result
    end

end

class TestClass

    def self.setup(&block)
        TestRunner.setup[self] ||= []
        TestRunner.setup[self].push(block)
    end

    def self.test(name, &block)
        t = TestInstance.new(name)
        block.call(t)
        TestRunner.tests[self] ||= []
        TestRunner.tests[self].push(t)
    end

    def self.cleanup(&block)
        TestRunner.cleanup[self] ||= []
        TestRunner.cleanup[self].push(block)
    end

end

module TestRunner

    @@setup   = {}
    @@cleanup = {}
    @@tests   = {}
    @@results = []
    @@runs    = []

    def self.results
        return @@results
    end

    def self.setup
        return @@setup
    end

    def self.tests
        return @@tests
    end

    def self.cleanup
        return @@cleanup
    end

    def self.finished?
        return @@runs.all? { |r| r.finished? }
    end

    def self.run_all(blocking=false)
        @@results = []
        @@tests.each do |test_class, tests|
            tests.each do |test_instance|
                result_list = []
                @@results.push(result_list)
                @@runs += run(test_instance, result_list, blocking)
            end
        end
    end

    def self.run(test_instance, result_list, blocking=false)
        if test_instance.cases.empty?
            raise "No arrange command for this test"
        end
        if test_instance.run_block.nil?
            raise "No run command for this test"
        end
        if test_instance.check_block.nil?
            raise "No check command for this test"
        end
        runs = []
        for i in 0...test_instance.cases.size do
            result_list[i] = OpenStruct.new
            test_run = TestRun.new(test_instance, i, result_list[i])
            runs.push(test_run)
            test_run.run
        end
        if blocking
            runs.each { |test_run| test_run.thread.join }
        end
        return runs
    end

    def self.print_results
        all_results = results.flatten
        successes = all_results.select { |r| r.success }
        failures  = all_results.select { |r| !r.success }

        indent = " " * 4
        margin = " " * 8
        list_item_prefix = "  * "

        title_left  = "#{successes.size} succeeded"
        title_right = "#{failures.size} failed"
        longest_named_test_result = successes.max_by { |r| r.test.name.to_s.length }
        max_name_length = longest_named_test_result&.test.name.to_s.length || 0
        max_column_size = [max_name_length, title_left.length].max + indent.length

        print indent
        print title_left.ljust(max_column_size)
        print margin
        print title_right
        print "\n"

        [successes.size, failures.size].max.times do |i|
            left_column = ""
            column_size = max_column_size
            if successes[i]
                left_column += list_item_prefix
                left_column += ConsoleStyle::FG_GREEN
                left_column += successes[i].test.name.to_s
                left_column += ConsoleStyle::RESET
                column_size += 9 # To account for hidden console string character
            else
                left_column += " "
            end
            print left_column.ljust(column_size)
            print margin
            if failures[i]
                print list_item_prefix
                print ConsoleStyle::FG_RED
                print failures[i].test.name
                print ConsoleStyle::RESET
            end
            print "\n"
        end
    end

    def print_breakdown
        # TODO: print all results and show any errors, and which test cases they're from.

        # all_results.each do |test_result|
        #     puts "Test #{test_result.test.name.to_s}:"
        #     puts test_result.success ? "Success" : !test_result.errors.empty? ? "Errored" : "Failure"
        #     # TODO: group by test suite
        #     # TODO: group by test instance
        #     # puts "All tests from #{test_class.name} Suite:"
        #     # tests.each do |test, cases|
        #         # cases.each do |test_result|
        #         # end
        #     # end
        # end
    end

end


#        print (i < s.size ? "  * " + result_colour(s[i]) + s[i][:test] + ConsoleStyle::RESET : " ").ljust(max_column_size + (i < s.size ? 9 : 0))
