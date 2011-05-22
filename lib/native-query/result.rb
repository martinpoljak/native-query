# encoding: utf-8
require "native-query/row"

module NativeQuery

    ##
    # Represents ORM query result.
    #
     
    class Result
    
        ##
        # Brings query object.
        #
        
        @query
        attr_reader :query
        
        ##
        # Constructor.
        #
        
        def initialize(query)
            @query = query
        end
        
        ##
        # Returns first field value of first record.
        #
        
        def single
            @query.single
        end
        
        ##
        # Returns one result row.
        #
        
        def one
            Row::new(@query.one)
        end 
        
        ##
        # Iterates through result.
        #
        
        def each
            @query.each do |row|
                yield Row::new(row)
            end
            
            self.free!
        end
        
        ##
        # Returns all rows.
        #
        
        def all
            self.map { |row| row }
        end
        
        ##
        # Returns data in complex associative level.
        #
        # According to limitations of equivalent MP::Fluent
        # method. Block is applied to all resultant rows.
        #

        def assoc(*args, &block)
            @query.assoc(args) do |row|
                result = Row::new(row)
                
                if block
                    result = block.call(result)
                end
                
                result  # returns
            end
        end
        
        ##
        # Returns count of the records.
        #
        
        def count
            @query.count
        end
        
        ##
        # Maps callback to array.
        #

        def map(&block)
            result = [ ]
            
            self.each do |item|
                result << block.call(item)
            end
            
            return result
        end
                                
        ##
        # Frees result resources.
        #

        def free!
            @query.free!
        end
        
    end
end
