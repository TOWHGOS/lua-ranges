---@generic T
---@param o T
---@return T
local function deepcopy(o, seen)
    seen = seen or {}
    if o == nil then
        return nil
    end
    if seen[o] then
        return seen[o]
    end

    local no
    if type(o) == "table" then
        no = {}
        seen[o] = no

        for k, v in next, o, nil do
            no[deepcopy(k, seen)] = deepcopy(v, seen)
        end
        setmetatable(no, deepcopy(getmetatable(o), seen))
    else
        no = o
    end
    return no
end

local array = {}
function array.allof(t, f)
    for i, v in ipairs(t) do
        if not f(v, i) then
            return false
        end
    end
    return true
end

function array.transform(t, f)
    local r = {}
    for i, v in ipairs(t) do
        local v1, v2 = f(v, i)
        if v2 then
            r[v1] = v2
        else
            table.insert(r, v1)
        end
    end
    return r
end

---@generic T: Range
---@param class T
---@return T
local function new(class, ...)
    local obj = setmetatable({}, { __index = class })
    ---@cast class Range
    class.Init(obj, ...)
    return obj
end

local ranges = {}

---@class Enumerator
---@field moveNext fun(): boolean
---@field kv fun(): any, any
---@field reset fun()
local PairEnumerator = {}

local function createPairEnumerator(next, range, key)
    local newEnumerator = {
        next = next,
        range = range,
        key = key,
        initKey = key
    }

    function newEnumerator.moveNext(this)
        this.key, this.value = this.next(this.range, this.key)
        return not not this.key
    end

    function newEnumerator.kv(this)
        return this.key, this.value
    end

    function newEnumerator.reset(this)
        this.key = this.initKey
    end

    return newEnumerator
end

local function reverse(key, value)
    return value, key
end

local function getValue(_, value)
    return value
end

local function getKey(key, _)
    return key
end

---@class Range
---@field enumerator Enumerator
Range = {}

function Range:Init(enumerator)
    self.enumerator = enumerator
end

---@generic T
---@return T
function Range:reset()
    self.enumerator:reset()
    return self
end

---@return Enumerator
function Range:copyEnumerator()
    local res = {}
    for k, v in next, self.enumerator do
        res[k] = v
    end
    res:reset()
    return res
end

function Range:first()
    self:reset()
    if self.enumerator:moveNext() then
        return self.enumerator:kv()
    end
end

function Range:firstKey()
    return getKey(self:first())
end

function Range:firstValue()
    return getValue(self:first())
end

function Range:count()
    self:reset()
    local count = 0
    while self.enumerator:moveNext() do
        count = count + 1
    end
    return count
end

function Range:iter()
    self:reset()
    return function()
        if self.enumerator:moveNext() then
            return self.enumerator:kv()
        end
    end
end

function Range:loopIter()
    return function()
        local reset
        if not self.enumerator:moveNext() then
            self:reset()
            reset = true
            if not self.enumerator:moveNext() then
                return
            end
        end
        local k, v = self.enumerator:kv()
        return k, v, reset
    end
end

---@class ValueRange: Range
ValueRange = setmetatable({}, { __index = Range })

---@class KeyValueRange: Range
KeyValueRange = setmetatable({}, { __index = Range })

---@param transformer fun(value, index:integer):any
---@return ValueRange
function ValueRange:iselect(transformer)
    local newEnumerator = { upstream = self:copyEnumerator() }

    function newEnumerator.moveNext(this)
        if this.upstream:moveNext() then
            this.i, this.v = this.upstream:kv()
            this.v = transformer(this.v, this.i)
            return true
        end
    end

    function newEnumerator.kv(this)
        return this.i, this.v
    end

    function newEnumerator.reset(this)
        this.upstream:reset()
    end

    return new(ValueRange, newEnumerator)
end

---@generic T
---@param transformer fun(key, value): T?
---@return ValueRange
function KeyValueRange:iselect(transformer)
    local newEnumerator = { upstream = self:copyEnumerator(), i = 0 }

    function newEnumerator.moveNext(this)
        if this.upstream:moveNext() then
            this.value = transformer(this.upstream:kv())
            this.i = this.i + 1
            return true
        end
    end

    function newEnumerator.kv(this)
        return this.i, this.value
    end

    function newEnumerator.reset(this)
        this.i = 0
        this.upstream:reset()
    end

    return new(ValueRange, newEnumerator)
end

---@param transformer fun(value: any, index:integer): any, any
---@return KeyValueRange
function ValueRange:select(transformer)
    local newEnumerator = { upstream = self:copyEnumerator() }

    function newEnumerator.moveNext(this)
        if this.upstream:moveNext() then
            this.i, this.v = this.upstream:kv()
            this.v, this.k = transformer(this.v, this.i --[[@as integer]])
            return true
        end
    end

    function newEnumerator.kv(this)
        return this.k or this.i, this.v
    end

    function newEnumerator.reset(this)
        this.upstream:reset()
    end

    return new(KeyValueRange, newEnumerator)
end

---@param predicate fun(value, index:integer):boolean
---@return boolean
function ValueRange:all(predicate)
    self:reset()
    while self.enumerator:moveNext() do
        if not predicate(reverse(self.enumerator:kv())) then
            return false
        end
    end

    return true
end

---@param predicate fun(value, index:integer):boolean
---@return boolean
function ValueRange:any(predicate)
    self:reset()
    while self.enumerator:moveNext() do
        if predicate(reverse(self.enumerator:kv())) then
            return true
        end
    end

    return false
end

---@param predicate fun(value, index:integer):any
---@return ValueRange
function ValueRange:where(predicate)
    local newEnumerator = { updatream = self:copyEnumerator(), i = 0 }

    function newEnumerator.moveNext(this)
        while this.updatream:moveNext() do
            local idx, value = this.updatream:kv()
            if predicate(value, idx --[[@as integer]]) then
                this.i = this.i + 1
                this.v = value
                return true
            end
        end
    end

    function newEnumerator.kv(this)
        return this.i, this.v
    end

    function newEnumerator.reset(this)
        this.i = 0
        this.updatream:reset()
    end

    return new(ValueRange, newEnumerator)
end

---@param predicate fun(key, value):any
---@return KeyValueRange
function KeyValueRange:where(predicate)
    local newEnumerator = { updatream = self:copyEnumerator() }

    function newEnumerator.moveNext(this)
        while this.updatream:moveNext() do
            if predicate(this.updatream:kv()) then
                return true
            end
        end
    end

    function newEnumerator.kv(this)
        return this.updatream:kv()
    end

    function newEnumerator.reset(this)
        this.updatream:reset()
    end

    return new(KeyValueRange, newEnumerator)
end

---@param transformer fun(key, value): any, any
---@return KeyValueRange
function KeyValueRange:select(transformer)
    local newEnumerator = { upstream = self:copyEnumerator() }

    function newEnumerator.moveNext(this)
        if this.upstream:moveNext() then
            this.k, this.v = this.upstream:kv()
            this.v, this.nk = transformer(this.k, this.v)
            return true
        end
    end

    function newEnumerator.kv(this)
        return this.nk or this.k, this.v
    end

    function newEnumerator.reset(this)
        this.upstream:reset()
    end

    return new(KeyValueRange, newEnumerator)
end

function KeyValueRange:items()
    return self:iselect(function(k, v)
        return { k, v }
    end)
end

function KeyValueRange:keys()
    return self:iselect(function(k)
        return k
    end)
end

function KeyValueRange:values()
    return self:iselect(function(_, v)
        return v
    end)
end

---@param ... ValueRange
---@return ValueRange
function ValueRange:zip(...)
    local newEnumerator = {
        updatream = ranges.fromArray { self, ... }:iselect(function(vr)
            return vr:copyEnumerator()
        end):toarray(),
        i = 0
    }

    function newEnumerator.moveNext(this)
        if array.allof(this.updatream, function(e)
                return e:moveNext()
            end) then
            this.i = this.i + 1
            this.v = array.transform(this.updatream, function(e)
                return getValue(e:kv())
            end)
            return true
        end
    end

    function newEnumerator.kv(this)
        return this.i, this.v
    end

    function newEnumerator.reset(this)
        this.i = 0
        for _, enuemrator in ipairs(this.updatream) do
            enuemrator:reset()
        end
    end

    return new(ValueRange, newEnumerator)
end

---@generic T
---@return T[]
function ValueRange:toarray()
    self:reset()
    local res = {}
    while self.enumerator:moveNext() do
        table.insert(res, getValue(self.enumerator:kv()))
    end
    return res
end

---@return table
function KeyValueRange:totable()
    self:reset()
    local res = {}
    while self.enumerator:moveNext() do
        local key, value = self.enumerator:kv()
        res[key] = value
    end
    return res
end

---@param n integer
---@return ValueRange
function ValueRange:skip(n)
    local newEnumerator = {
        upstream = self:copyEnumerator(),
        i = 0,
        count = n
    }

    function newEnumerator.moveNext(this)
        while this.i < this.count do
            this.i = this.i + 1
            if not this.upstream:moveNext() then
                return
            end
        end

        this.i = this.i + 1
        if this.upstream:moveNext() then
            this.v = getValue(this.upstream:kv())
            return true
        end
    end

    function newEnumerator.kv(this)
        return this.i, this.v
    end

    function newEnumerator.reset(this)
        this.upstream:reset()
        this.i = 0
    end

    return new(ValueRange, newEnumerator)
end

---@param n integer
---@return ValueRange
function ValueRange:take(n)
    local newEnumerator = {
        upstream = self:copyEnumerator(),
        i = 0,
        count = n
    }

    function newEnumerator.moveNext(this)
        this.i = this.i + 1
        if this.upstream:moveNext() and this.i <= this.count then
            this.v = getValue(this.upstream:kv())
            return true
        end
    end

    function newEnumerator.kv(this)
        return this.i, this.v
    end

    function newEnumerator.reset(this)
        this.upstream:reset()
        this.i = 0
    end

    return new(ValueRange, newEnumerator)
end

---@generic T
---@param f? fun(value, index?: integer): T
---@return ValueRange
function ValueRange:distinct(f)
    local newEnumerator = {
        upstream = self:copyEnumerator(),
        i = 0,
        set = {},
        f = f or getKey
    }

    function newEnumerator.moveNext(this)
        while this.upstream:moveNext() do
            local i, v = this.upstream:kv()
            local k = this.f(v, i)
            if not this.set[k] then
                this.set[k] = true
                this.i = this.i + 1
                this.v = v
                return true
            end
        end
        return false
    end

    function newEnumerator.kv(this)
        return this.i, this.v
    end

    function newEnumerator.reset(this)
        this.upstream:reset()
        this.i = 0
        this.set = {}
    end

    return new(ValueRange, newEnumerator)
end

---@param size integer
---@param discardRemainders? boolean
---@return ValueRange
function ValueRange:slice(size, discardRemainders)
    local newEnumerator = {
        upstream = self:copyEnumerator(),
        i = 0
    }

    function newEnumerator.moveNext(this)
        this.v = nil
        if this.e then
            return false
        end
        local newValue = {}
        for i = 1, size do
            if not this.upstream:moveNext() then
                this.e = true
                if discardRemainders or i == 1 then
                    return false
                else
                    break
                end
            end
            table.insert(newValue, getValue(this.upstream:kv()))
        end
        this.v = newValue
        this.i = this.i + 1
        return true
    end

    function newEnumerator.kv(this)
        return this.i, this.v
    end

    function newEnumerator.reset(this)
        this.upstream:reset()
        this.i = 0
        this.v = nil
        this.e = nil
    end

    return new(ValueRange, newEnumerator)
end

function ValueRange:sum()
    self:reset()
    local res = nil
    while self.enumerator:moveNext() do
        res = (res or 0) + getValue(self.enumerator:kv())
    end
    return res
end

---@generic T
---@param f? fun(lhs: T, rhs: T): T
function ValueRange:max(f)
    self:reset()
    return (f and f ~= math.max)
        and self:aggregate(f)
        or self:apply(math.max)
end

---@generic T
---@param f? fun(lhs: T, rhs: T): T
function ValueRange:min(f)
    self:reset()
    return (f and f ~= math.min)
        and self:aggregate(f)
        or self:apply(math.min)
end

---@param sep? string|number
---@return string
function ValueRange:concat(sep)
    self:reset()
    sep = sep or ""
    local res = nil
    while self.enumerator:moveNext() do
        local v = getValue(self.enumerator:kv())
        res = res and res .. sep .. v or v
    end
    return res or ""
end

---@generic T
---@param f fun(acc: T, value: any, index?: integer): T
---@param seed? T
---@return T
function ValueRange:aggregate(f, seed)
    self:reset()
    if not seed and self.enumerator:moveNext() then
        seed = getValue(self.enumerator:kv())
    end
    while self.enumerator:moveNext() do
        seed = f(seed, reverse(self.enumerator:kv()))
    end
    return seed
end

---@generic T
---@param f fun(acc: T, key: any, value): T
---@param seed T
---@return T
function KeyValueRange:aggregate(f, seed)
    while self.enumerator:moveNext() do
        seed = f(seed, self.enumerator:kv())
    end
    return seed
end

---@param skipReset? boolean
---@return ...
function ValueRange:unpack(skipReset)
    if not skipReset then
        self:reset()
    end
    if self.enumerator:moveNext() then
        return getValue(self.enumerator:kv()), self:unpack(true)
    end
end

---@generic T
---@param f fun(...): T
---@return T
function ValueRange:apply(f)
    return f(self:unpack())
end

---@param f fun(value, index?: integer)
function ValueRange:foreach(f)
    self:reset()
    while self.enumerator:moveNext() do
        f(reverse(self.enumerator:kv()))
    end
end

---@param f fun(key, value)
function KeyValueRange:foreach(f)
    self:reset()
    while self.enumerator:moveNext() do
        f(self.enumerator:kv())
    end
end

---@param range table
---@return KeyValueRange
function ranges.fromTable(range)
    return new(KeyValueRange, createPairEnumerator(pairs(range or {})))
end

---@generic T
---@param range T[]
---@return ValueRange
function ranges.fromArray(range)
    return new(ValueRange, createPairEnumerator(ipairs(range or {})))
end

---@param from integer
---@param to? integer
---@param step? integer
---@return ValueRange
function ranges.range(from, to, step)
    local newEnumerator = {
        from = from,
        to = to,
        step = step or 1,
        i = 0,
        v = from - (step or 1)
    }

    function newEnumerator.moveNext(this)
        this.v = this.v + this.step
        this.i = this.i + 1
        if not this.to then
            return true
        end
        if this.step > 0 then
            return this.v <= this.to
        else
            return this.v >= this.to
        end
    end

    function newEnumerator.kv(this)
        return this.i, this.v
    end

    function newEnumerator.reset(this)
        this.i = 0
        this.v = this.from - this.step
    end

    return new(ValueRange, newEnumerator)
end

---@generic T
---@param g fun(): T
---@param count? integer
---@return ValueRange
function ranges.generate(g, count)
    local newEnumerator = { g = g, i = 0, count = count }

    function newEnumerator.moveNext(this)
        this.i = this.i + 1
        if not this.count or this.i <= this.count then
            this.v = this.g()
            return this.v ~= nil
        end
    end

    function newEnumerator.kv(this)
        return this.i, this.v
    end

    function newEnumerator.reset(this)
        this.i = 0
    end

    return new(ValueRange, newEnumerator)
end

---@param value any
---@param count? integer
---@return ValueRange
function ranges.rep(value, count)
    return ranges.generate(function()
        return deepcopy(value)
    end, count)
end

function ranges.zip(value, ...)
    return ranges.fromArray(value)
        :zip(ranges.fromArray { ... }
            :iselect(ranges.fromArray)
            :unpack())
end

return ranges
