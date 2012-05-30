# encoding: utf-8

module NativeQuery

    ##
    # Represents one ORM row.
    #
     
    class Row
    
        ##
        # Brings data.
        #
        
        @data
        
        ##
        # Processed data cache.
        #
        
        @__data
        
        ##
        # Constructor.
        #
        
        def initialize(data)
            @data = data
        end
        
        ##
        # Maps unknown calls to data fields. 
        #
        
        def method_missing(sym, *args)
            __data[sym]
        end
        
        ##
        # Indicates, rows exists.
        #
        
        def any?
           not __data.nil? 
        end
        
        ##
        # Converts to hash.
        #
        
        def to_hash
            __data.to_hash
        end
        
        ##
        # Returns data field.
        #
        
        private
        def __data
            @data
=begin
            if @__data.nil?
           
                # Calls for data and converts string keys of hash 
                # to symbols.
                
                data = @data
                @__data = { }
                
                if not data.nil?
                    @data = nil
                    
                    data.each_pair do |k, v|
                        @__data[k.to_sym] = v
                    end
                else
                    @__data = nil
                end
                
            end

            return @__data
=end
        end
    end
end
