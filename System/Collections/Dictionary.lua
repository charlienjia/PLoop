--===========================================================================--
--                                                                           --
--                       System.Collections.Dictionary                       --
--                                                                           --
--===========================================================================--

--===========================================================================--
-- Author       :   kurapica125@outlook.com                                  --
-- URL          :   http://github.com/kurapica/PLoop                         --
-- Create Date  :   2016/02/28                                               --
-- Update Date  :   2018/03/16                                               --
-- Version      :   1.0.0                                                    --
--===========================================================================--

PLoop(function(_ENV)
    namespace "System.Collections"

    import "System.Serialization"

    --- Represents the key-value pairs collections
    interface "IDictionary" { Iterable }

    --- The default dictionary
    __Sealed__() __Serializable__() __Template__( Any, Any )
    class "Dictionary" (function (_ENV, keytype, valtype)
        extend "IDictionary" "ISerializable"

        export {
            ipairs              = ipairs,

            List[keytype], List[valtype]
        }

        -----------------------------------------------------------
        --                     serialization                     --
        -----------------------------------------------------------
        function Serialize(self, info)
            local key   = {}
            local val   = {}
            local idx   = 1
            for k, v in self:GetIterator() do
                key[idx]= k
                val[idx]= v
                idx     = idx + 1
            end

            info:SetValue(1, List[keytype](key))
            info:SetValue(2, List[valtype](val))
        end

        __Arguments__{ SerializationInfo }
        function __new(_, info)
            local key     = info:GetValue(1, List[keytype])
            local val     = info:GetValue(2, List[valtype])

            return this(_, key, val)
        end

        -----------------------------------------------------------
        --                        method                         --
        -----------------------------------------------------------
        GetIterator     = pairs

        -----------------------------------------------------------
        --                      constructor                      --
        -----------------------------------------------------------
        __Arguments__{ }
        function __new() return {} end

        __Arguments__{ RawTable }
        function __new(_, dict) return dict, true end

        __Arguments__{ RawTable, RawTable }
        function __new(_, lstKey, lstValue)
            local dict  = {}
            local iter, o, idx, value = ipairs(lstValue)
            for _, key in ipairs(lstKey) do
                idx, value = iter(o, idx)
                if idx then
                    dict[key] = value
                else
                    break
                end
            end
            return dict, true
        end

        __Arguments__{ IDictionary }
        function __new(_, dict)
            local dict  = {}
            for key, value in dict:GetIterator() do
                dict[key] = value
            end
            return dict, true
        end

        __Arguments__{ IList, IList }
        function __new(_, lstKey, lstValue)
            local dict  = {}
            local iter, o, idx, value = lstValue:GetIterator()
            for _, key in lstKey:GetIterator() do
                idx, value = iter(o, idx)
                if idx then
                    dict[key] = value
                else
                    break
                end
            end
            return dict, true
        end

        __Arguments__{ Callable, Variable.Optional(), Variable.Optional() }
        function __new(_, iter, obj, idx)
            local dict  = {}
            for key, value in iter, obj, idx do
                dict[key] = value
            end
            return dict, true
        end
    end)

    --- the dictionary stream worker, used to provide stream filter, map and
    -- etc operations on a dictionary without creating any temp caches
    __Final__() __Sealed__() __SuperObject__(false)
    class "DictionaryStreamWorker" (function (_ENV)
        extend "IDictionary"

        export {
            type                = type,
            yield               = coroutine.yield,
            tinsert             = table.insert,
            tremove             = table.remove,
        }

        -----------------------------------------------------------
        --                        helpers                        --
        -----------------------------------------------------------
        local getIdleworkers
        local rycIdleworkers

        if Platform.MULTI_OS_THREAD then
            export { Context }

            getIdleworkers      = function()
                local context   = Context.Current
                return context and context[DictionaryStreamWorker]
            end

            rycIdleworkers      = function(worker)
                local context   = Context.Current
                if context then context[DictionaryStreamWorker] = worker end
            end
        else
            -- Keep idle workers for re-usage
            export { idleworkers= {} }
            getIdleworkers      = function() return tremove(idleworkers) end
            rycIdleworkers      = function(worker) tinsert(idleworkers, worker) end
        end

        -----------------------------------------------------------
        --                       constant                        --
        -----------------------------------------------------------
        export {
            FLD_TARGETDICT      = 0,
            FLD_MAPACTITON      = 1,
            FLD_FILTERACTN      = 2,
        }
        -----------------------------------------------------------
        --                        method                         --
        -----------------------------------------------------------
        __Iterator__()
        function GetIterator(self)
            local targetDict    = self[FLD_TARGETDICT]
            local map           = self[FLD_MAPACTITON]
            local filter        = self[FLD_FILTERACTN]

            -- Clear self and put self into recycle
            self[FLD_TARGETDICT] = nil
            self[FLD_MAPACTITON] = nil
            self[FLD_FILTERACTN] = nil

            rycIdleworkers(self)

            -- Generate the iterator
            local dowork

            -- Generate the do-work
            if filter then
                -- Check Function
                if map then
                    for key, value in targetDict:GetIterator() do
                        if filter(key, value) then yield(key, map(key, value)) end
                    end
                else
                    for key, value in targetDict:GetIterator() do
                        if filter(key, value) then yield(key, value) end
                    end
                end
            else
                -- No filter
                if map then
                    for key, value in targetDict:GetIterator() do
                        yield(key, map(key, value))
                    end
                else
                    for key, value in targetDict:GetIterator() do
                        yield(key, value)
                    end
                end
            end
        end

        -----------------------------------------------------------
        --                     Queue method                      --
        -----------------------------------------------------------
        --- Map the items to other type datas
        __Arguments__{ Callable }
        function Map(self, func) self[FLD_MAPACTITON] = func return self end

        --- Used to filter the items with a check function
        __Arguments__{ Callable }
        function Filter(self, func) self[FLD_FILTERACTN] = func return self end

        -----------------------------------------------------------
        --                      constructor                      --
        -----------------------------------------------------------
        __Arguments__{ IDictionary }
        function DictionaryStreamWorker(self, dict)
            self[FLD_TARGETDICT] = dict
        end

        -----------------------------------------------------------
        --                      meta-method                      --
        -----------------------------------------------------------
        __Arguments__{ IDictionary }
        function __exist(_, dict)
            local worker = getIdleworkers()
            if worker then worker[FLD_TARGETDICT] = dict end
            return worker
        end
    end)

    __Sealed__()
    interface "IDictionary" (function (_ENV)
        export {
            yield               = coroutine.yield,
        }

        export { DictionaryStreamWorker, ListStreamWorker }

        -----------------------------------------------------------
        --                     Queue method                      --
        -----------------------------------------------------------
        --- Map the items to other type datas
        __Arguments__{ Callable }
        function Map(self, func) return DictionaryStreamWorker(self):Map(func) end

        --- Used to filter the items with a check function
        __Arguments__{ Callable }
        function Filter(self, func) return DictionaryStreamWorker(self):Filter(func) end

        -----------------------------------------------------------
        --                     Final method                      --
        -----------------------------------------------------------
        --- Combine the key-value pairs to get a result
        __Arguments__{ Callable, Variable.Optional()}
        function Reduce(self, func, init)
            for key, value in self:GetIterator() do init = func(key, value, init) end
            return init
        end

        --- Call the function for each element or set property's value for each element
        __Arguments__{ Callable, Variable.Rest() }
        function Each(self, func, ...) for key, value in self:GetIterator() do func(key, value, ...) end end

        --- get the keys
        __Iterator__()
        function GetKeys(self)
            local index = 0
            for key in self:GetIterator() do
                index = index + 1
                yield(index, key)
            end
        end

        -- get the values
        __Iterator__()
        function GetValues(self)
            local index = 0
            for _, value in self:GetIterator() do
                index = index + 1
                yield(index, value)
            end
        end

        -----------------------------------------------------------
        --                     list property                     --
        -----------------------------------------------------------
        --- Get a list stream worker of the dictionary's keys
        property "Keys" {
            Get = function (self)
                return ListStreamWorker( self:GetKeys() )
            end
        }

        --- Get a list stream worker of the dictionary's values
        property "Values" {
            Get = function (self)
                return ListStreamWorker( self:GetValues() )
            end
        }
    end)
end)
