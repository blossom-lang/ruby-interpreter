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
            return false
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

        def find(args)
            if !args.empty?
                if @type.nil?
                    i = 0
                else
                    i = args.find_index { |a| Options::TypeChecker.is_type?(a, @type) }
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
                return true
            end
            return false
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

        def find(args)
            args.each_with_index do |arg, i|
                if @commands.include?(arg)
                    args.delete_at(i)
                    @present = true
                    if @group
                        @group.value = @flag_value
                    else
                        @value = true
                    end
                    return true
                end
            end
            return false
        end

        def find_switch(switches)
            return if @switch.nil?
            if switches.include?(@switch)
                switches.tr!(@switch, "")
                # TODO: Should i set group value here??
                @present = true
                @value = true
                return true
            end
            return false
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

        attr_reader :present

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

        def find(args)
            args.each_with_index do |arg, i|
                if @prefixes.include?(arg) && i + @types.size < args.size
                    captures = args[i+1..i+@types.size]
                    values = []
                    captures.each_with_index do |capture, i|
                        if Options::TypeChecker.is_type?(capture, @types[i])
                            values.push(capture)
                        else
                            raise "Provided argument '#{capture}' needs to be the #{@types[i]} type."
                        end
                    end
                    args.slice!(i..i+@types.size)
                    @present = true
                    if @group
                        @group.value = @types.size == 1 ? values[0] : values
                    else
                        @value = @types.size == 1 ? values[0] : values
                    end
                    return true
                end
            end
            return false
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

    class TypeChecker

        @@type_regexes = {
            'FILE'   => /[\\\w\.\/]+\.\w+/,
            'DIR'    => /[\\\w\.\/]+/,
            'PATH'   => /[\\\w\.\/]+/,
            'STRING' => /.+/,
        }

        def self.is_type?(arg, type_name)
            return true if type_name.nil?
            return false if !(arg =~ @@type_regexes[type_name])
            # TODO: more type checking (for file/dir)
            # CLI error Code from here:
            # https://unix.stackexchange.com/a/326811
            # EPERM   1  Operation not permitted
            # ENOENT  2  No such file or directory
            # E2BIG   7  Argument list too long
            # ENOEXEC 8  Exec format error
            # EBADF   9  Bad file descriptor
            # ECHILD  10 No child processes
            # EAGAIN  11 Resource temporarily unavailable
            # ENOMEM  12 Cannot allocate memory
            # EACCES  13 Permission denied
            # EEXIST  17 File exists
            # ENOTDIR 20 Not a directory
            # EISDIR  21 Is a directory
            return true
        end

    end

    @@usage_header = ""
    @@usage_string = nil
    @@usage_footer = ""
    @@help_commands = []
    @@commands = []

    @@enclosing_group = false

    def self.help(&block)
        settings = OpenStruct.new
        block.call(settings)
        @@help_commands = settings.commands || []
        @@usage_header = settings.header || ""
        @@usage_footer = settings.footer || ""
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

        # 0th pass:
        #     check for help flags
        @@help_commands.each do |param|
            if args.any? { |a| a == param }
                puts usage
                exit(0)
            end
        end


        errors = []
        # 1st pass:
        #     check for any switches / switch lists
        switch_lists = args.select { |arg| arg =~ /(?<![\-\w])\-[a-zA-Z]+/ }
        switches = switch_lists.inject("") { |memo, list| memo += list[1..-1] }
        @@commands.each do |param|
            if param.is_a?(Objects::Flag)
                found = param.find_switch(switches)
            end
        end
        # 2nd pass:
        #     go through every required flag and value option and extract the args (and following args as necessary)
        @@commands.each do |param|
            if param.required && (param.is_a?(Objects::Flag) || param.is_a?(Objects::Value)) && !param.present
                begin
                    found = param.find(args)
                rescue StandardError => e
                    errors.push(e.to_s)
                end
                if !found
                    errors.push("A #{param.name.to_s} argument is required")
                end
            end
        end
        # 3rd pass:
        #     go through every non-required non-positional option and extract if there are matches
        @@commands.each do |param|
            if !param.required && !param.is_a?(Objects::Positional) && !param.is_a?(Objects::Group)
                begin
                    found = param.find(args)
                rescue StandardError => e
                    errors.push(e.to_s)
                end
            end
        end
        # 4th pass:
        #     all remaining args should be positional at this point
        #     go through required positional args and extract them
        @@commands.each do |param|
            if param.required && param.is_a?(Objects::Positional)
                begin
                    found = param.find(args)
                rescue StandardError => e
                    errors.push(e.to_s)
                end
                if !found
                    errors.push("A #{param.name.to_s} argument is required")
                end
            end
        end
        # 4th pass:
        #     go through positional args that are part of required groups and extract them
        @@commands.each do |param|
            if param.is_a?(Objects::Positional) && param.group && param.group.required && !param.group.value
                begin
                    found = param.find(args)
                rescue StandardError => e
                    errors.push(e.to_s)
                end
                if !found
                    errors.push("A #{param.name.to_s} argument is required")
                end
            end
        end        
        # Make sure any required groups have values.
        @@commands.each do |param|
            if param.is_a?(Objects::Group) && param.required && param.value.nil?
                errors.push "A #{param.name.to_s} argument is required"
            end
        end
        
        options = OpenStruct.new
        @@commands.each do |param|
            options[param.name] = param.value
        end

        if !errors.empty?
            errors.uniq.each do |err|
                $stderr.puts err
            end
            exit(22)
        end

        return options
    end

    def self.usage
        if @@usage_string.nil?
            @@usage_string = @@usage_header + "\n"         
            # TODO: generate usage string from @@commands
            @@usage_string += @@usage_footer
        end
        return @@usage_string
    end

    def self.to_s
        return usage
    end

end