require 'ostruct'

module Objects

    class Base

        attr_reader :value
        attr_reader :required
        attr_reader :group

        def name
            if @group
                return @group.name
            else
                return @name
            end
        end

        def find(args, types)
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
            @type = settings.type || nil
            if group
                @group = group
            else
                raise "A positional option needs a name" if settings.name.nil?
                @name        = settings.name
                @required    = settings.required.nil? ? false : settings.required
                @description = settings.description || ""
            end
        end

        def find(args, types)
            type_regex = types[@type]
            if !args.empty?
                if type_regex.nil?
                    i = 0
                else
                    i = args.find_index { |a| a =~ type_regex}
                end
                if i.nil?
                    raise "Provided argument '#{args[0]}' needs to be the #{@type} type."
                end
                value = args[i]
                args.delete_at(i)
                if @group
                    @group.value = value
                else
                    @value = value
                end
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
            raise "An options flag needs a commands list" if settings.commands.nil?
            @commands = settings.commands

            if group
                raise "A group option needs a value" if settings.value.nil?
                @flag_value = settings.value
                @group = group
            else
                raise "An options flag needs a name" if settings.name.nil?
                @name        = settings.name
                @required    = settings.required.nil? ? false : settings.required
                @default     = settings.default || nil
                @switch      = settings.switch || nil
                @description = settings.description || ""
            end
            @present = false
        end

        def find(args, types)
            args.each_with_index do |arg, i|
                if @commands.include?(arg)
                    args.delete_at(i)
                    @present = true
                    if @group
                        @group.value = @flag_value
                    else
                        @value = true
                    end
                end
            end
        end

        def find_switch(switches)
            return if @switch.nil?
            if switches.include?(@switch)
                switches.tr!(@switch, "")
                @present = true
                # TODO: set group value here?
                @value   = true
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
            raise "A value option needs a prefix. Otherwise, use a positional option" if settings.prefixes.nil? || settings.prefixes.empty?
            raise "A value option needs a type list" if settings.types.nil? || settings.types.empty?
            @prefixes = settings.prefixes
            @types    = settings.types
            if group
                @group = group
            else
                raise "A value option needs a name" if settings.name.nil?
                @name        = settings.name
                @required    = settings.required.nil? ? false : settings.required
                @default     = settings.default || nil
                @description = settings.description || ""
            end
            @present = false
        end

        def find(args, types)
            args.each_with_index do |arg, i|
                if @prefixes.include?(arg) && i + @types.size < args.size
                    captures = args[i+1..i+@types.size]
                    values = []
                    arg_types = types.keys
                    captures.each_with_index do |capture, i|
                        if capture =~ types[arg_types[i]]
                            values.push(capture)
                        else
                            raise "Provided argument '#{capture}' needs to be the #{arg_types[i]} type."
                        end
                    end
                    args.slice!(i..i+@types.size)
                    @present = true
                    if @group
                        @group.value = @types.size == 1 ? values[0] : values
                    else
                        @value = @types.size == 1 ? values[0] : values
                    end
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

        attr_reader :options
        attr_writer :value

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
        'FILE'   => /[\\\w\.\/]+\.\w+/,
        'DIR'    => /[\\\w\.\/]+/,
        'PATH'   => /[\\\w\.\/]+/,
        'STRING' => /.+/,
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
        o = Objects::Positional.new(settings, @@enclosing_group)
        @@commands.push(o)
        return o
    end

    def self.flag(&block)
        settings = OpenStruct.new
        block.call(settings)
        f = Objects::Flag.new(settings, @@enclosing_group)
        @@commands.push(f)
        return f
    end
 
    def self.value(&block)
        settings = OpenStruct.new
        block.call(settings)
        v = Objects::Value.new(settings, @@enclosing_group)
        @@commands.push(v)
        return v
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
        return g
    end

    def self.parse(args=nil)
        args ||= [*ARGV]
        # 1st pass:
        #     go through every required flag and value option and extract the args (and following args as necessary)
        @@commands.each do |param|
            if param.required && param.is_a?(Objects::Flag) && !param.is_a?(Objects::Value)
                param.find(args, @@type_regexes)
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
                param.find(args, @@type_regexes)
            end
        end
        # 4th pass:
        #     all remaining args should be positional at this point
        #     go through required positional args and extract them
        @@commands.each do |param|
            if param.required && param.is_a?(Objects::Positional)
                param.find(args, @@type_regexes)
            end
        end
        # 4th pass:
        #     go through positional args that are part of required groups and extract them
        @@commands.each do |param|
            if param.is_a?(Objects::Positional) && param.group && param.group.required && !param.group.value
                param.find(args, @@type_regexes)
            end
        end        
        # Make sure any required groups have values.
        @@commands.each do |param|
            if param.is_a?(Objects::Group) && param.required && param.value.nil?
                raise "An argument for #{param.name.to_s} is required."
            end
        end
        
        options = OpenStruct.new
        @@commands.each do |param|
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