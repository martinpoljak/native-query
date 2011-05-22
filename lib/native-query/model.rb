# encoding: utf-8
require "fluent-query/connection"
require "native-query/query"

module NativeQuery

    ##
    # Represents instance of ORM model.
    #
     
    class Model
    
        ##
        # Brings database connection object.
        #
        
        @connection
        
        ##
        # Brings driver setting.
        #
        
        @driver
        
        ##
        # Brings database connection configuration setting.
        #
        
        @configuration
        
        ##
        # Constructor.
        #
        
        def initialize(driver, configuration)
            @driver = driver
            @configuration = configuration
        end
        
        ##
        # Returns connection.
        #
        
        def connection
            if not @connection
                @connection = FluentQuery::Connection::new(@driver, @configuration) 
            end
            
            @connection    # returns
        end
        
        ##
        # Maps missing calls to tables.
        #
        # Arguments are expected to be field names, so given to 
        # field query method.
        #
        
        def method_missing(sym, *args, &block)
            query = Query::new(self.connection, sym)
            
            if args and not args.empty?
                query.fields(*args)
            end
            
            if block
                result = query.instance_eval(&block)
            else
                result = query
            end

            return result
        end
        
    end
end
