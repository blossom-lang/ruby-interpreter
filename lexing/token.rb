class Token

    attr_reader :name
    attr_reader :lexeme
    attr_reader :line
    attr_reader :column
    attr_reader :filename
    attr_reader :literal

    def initialize(name, lexeme, line, column, filename, literal=nil)
        @name     = name
        @lexeme   = lexeme
        @line     = line
        @column   = column
        @filename = filename
        @literal  = literal
    end

    def to_s
        return @name.to_s + " '" + @lexeme + "' " + (@literal.nil? ? "" : @literal.to_s)
    end

    def self.system(lexeme, system_part)
        return Token.new(:SYSTEM_FUNCTION, lexeme, 0, 0, system_part)
    end

end