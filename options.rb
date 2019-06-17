require 'ostruct'

module Objects

    class Base

        attr_reader :value
        attr_reader :required

        def name
            if @group
                return @group.name
            else
                return @name
            end
        end

        def find(args)
        end

    end

    #
    # Positional
    #
    #   - name
    #   - required
    #   - type
    #   - description
    #
    class Positional < Base

        def initialize(settings, group=nil)
            if group
                @group = group
            else
                raise "A positional option needs a name" if settings.name.nil?
                @name        = settings.name
                @required    = settings.required.nil? ? false : settings.required
                @type        = settings.type || nil
                @description = settings.description || ""
            end
        end

    end

    #
    # Flag
    #
    #   - name
    #   - required
    #   - default
    #   - commands
    #   - switch
    #   - description
    #
    class Flag < Base

        attr_reader :present

        def initialize(settings, group=nil)
            if group
                raise "A group option needs a value" if settings.value.nil?
                @value = settings.value
                @group = group
            else
                raise "An options flag needs a name" if settings.name.nil?
                raise "An options flag needs a commands list" if settings.commands.nil?
                @name        = settings.name
                @commands    = settings.commands
                @required    = settings.required.nil? ? false : settings.required
                @default     = settings.default || nil
                @switch      = settings.switch || nil
                @description = settings.description || ""
            end
            @present = false
        end

        def find(args)
            args.each_with_index do |arg, i|
                if @commands.include?(arg)
                    args.delete_at(i)
                    @present = true
                end
            end
        end

        def find_switch(switches)
            return if @switch.nil?
            if switches.include?(@switch)
                switches.tr!(@switch, "")
                @present = true
            end
        end

    end

    #
    # Value
    #
    #   - name
    #   - required
    #   - default
    #   - types
    #   - prefixes
    #   - description
    #
    class Value < Base

        def initialize(settings, group=nil)
            if group
                @group = group
            else
                raise "A value option needs a name" if settings.name.nil?
                raise "A value option needs a type list" if settings.types.nil? || settings.types.empty?
                raise "A value option needs a prefix. Otherwise, use a positional option" if settings.prefixes.nil? || settings.prefixes.empty?
                @name        = settings.name
                @types       = settings.types
                @prefixes    = settings.prefixes
                @required    = settings.required.nil? ? false : settings.required
                @default     = settings.default || nil
                @description = settings.description || ""
            end
            @present = false
            @values  = []
        end

        def find(args)
            args.each_with_index do |arg, i|
                if @prefixes.include?(arg) && i + @types.size < args.size
                    values = args[i...i+@types.size] # TODO: test these ranges
                    args.slice!(i...i+@types.size)
                    @present = true
                    @values = values
                end
            end
        end

    end

    #
    # Group
    #
    #   - name
    #   - required
    #   - default
    #   - options
    #   - description
    #
    # Note: Child options of a group can't have a name or required field.
    #       They must, however, all have value fields (unless they are positional or value options - which use the args as the values)
    #       Nested groups are not supported.
    #
    class Group < Base

        def initialize
        end

        def setup(settings, group=nil)
            raise "Nested group options are not supported" if group
            raise "A group option needs a name" if settings.name.nil?
            raise "A group option needs a list of options" if settings.options.nil? || settings.options.empty?
            @name        = settings.name
            @options     = settings.options
            @required    = settings.required.nil? ? false : settings.required
            @default     = settings.default || nil
            @description = settings.description || ""
        end

    end

end

class Options

    @@type_regexes = {
        'FILE'   => //,
        'DIR'    => //,
        'PATH'   => //,
        'STRING' => //,
    }

    @@usage_header = ""
    @@usage_string = nil
    @@usage_footer = ""
    @@help_commands = []
    @@commands = []

    @@enclosing_group = false

    def self.help(&block)
        settings = OpenStruct.new
        block.call(settings)
        @@help_commands = settings.commands
        @@usage_header = settings.header
        @@usage_footer = settings.footer
    end

    def self.positional(&block)
        settings = OpenStruct.new
        block.call(settings)
        p = Objects::Positional.new(settings, @@enclosing_group)
        @@commands.push(p)
    end

    def self.flag(&block)
        settings = OpenStruct.new
        block.call(settings)
        f = Objects::Flag.new(settings, @@enclosing_group)
        @@commands.push(f)
    end
 
    def self.value(&block)
        settings = OpenStruct.new
        block.call(settings)
        v = Objects::Value.new(settings, @@enclosing_group)
        @@commands.push(v)
    end

    def self.group(&block)
        settings = OpenStruct.new
        g = Objects::Group.new
        outer_group = @@enclosing_group
        @@enclosing_group = g
        block.call(settings)
        @@enclosing_group = outer_group
        g.setup(settings, @@enclosing_group)
        @@commands.push(g)
    end

    def self.parse(args=nil)
        args ||= [*ARGV]
        # 1st pass:
        #     go through every required option and extract the args (and following args as necessary)
        #     error if any are missing or wrongly typed or whatever
        @@commands.each do |param|
            if param.required && !param.is_a?(Objects::Positional) && !param.is_a?(Objects::Group)
                param.find(args)
            end
        end
        # 2nd pass:
        #     check for any switches / switch lists
        switch_lists = args.select { |arg| arg =~ /(?<![\-\w])\-[a-zA-Z]+/ }
        switches = switch_lists.inject("") { |memo, list| memo += list[1..-1] }
        @@commands.each do |param|
            if param.is_a?(Objects::Flag) && !param.present
                param.find_switch(switches)
            end
        end
        # 3rd pass:
        #     go through every non-required non-positional option and extract if there are matches
        @@commands.each do |param|
            if !param.required && !param.is_a?(Objects::Positional) && !param.is_a?(Objects::Group)
                param.find(args)
            end
        end

        # 4th pass:
        #     go through all groups with no positional args
        #     go through all groups with positional args

        # 5th pass:
        #     extract all required positional args
        #     extract all non-required positional args

        # TODO: generate ostruct with results (name => value)
        options = OpenStruct.new
        @@commands.each do |param|
            # p param.class
            # p param.name
            # p param
            # puts
            options[param.name] = param.value
        end
        return options
    end

    def self.to_s
        if @@usage_string.nil?
            @@usage_string = @@usage_header + "\n"         
            # TODO: generate usage string from @@commands
            @@usage_string += @@usage_footer
        end
        return @@usage_string
    end

end