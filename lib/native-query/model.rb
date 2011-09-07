# encoding: utf-8
require "fluent-query/connection"
require "native-query/query"
require "hash-utils/object"
require "set"

module NativeQuery

    ##
    # Represents instance of ORM model.
    #
     
    class Model
    
        ##
        # Indicates relevant methods for binding to the 
        # connection object.
        #
        
        RELEVANT_METHODS = Set::new [
            :insert, :update, :delete, :begin, :commit, :rollback, :transaction
        ]
    
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
            
            # If it's binding to the connection
            if sym.in? Model::RELEVANT_METHODS
                return self.connection.send(sym, *args, &block)
                
            # In otherwise, it's query request
            else
                query = Query::new(self.connection, sym)
                
                if args and not args.empty?
                    query.fields(*args)
                end
                
                if not block.nil?
                    result = query.instance_eval(&block)
                else
                    result = query
                end

                return result
            end
            
        end
        
    end
end
