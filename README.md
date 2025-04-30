[![License](http://img.shields.io/badge/Licence-MIT-brightgreen.svg)](LICENSE)

# What's this?
A Linq-lick library for lua

# How to use

- require
```lua
local ranges = require "ranges"
```

- filter
```lua
local a = ranges.fromArray { 1, 2, 3 }
    :where(function(value)
        return value % 2 ~= 0
    end)
    :toarray() -- { 1, 3 }
```

- transform
```lua
local a = ranges.fromArray { 11, 22, 33 }
    :iselect(function(value, index)
        return value + index
    end)
    :toarray() -- { 12, 24, 36 }
```
```lua
local a = ranges.fromArray { 11, 22, 33 }
    :select(function(value, index)
        return value + index, "item" .. index
    end)
    :totable() --[[ {
        item1 = 12,
        item2 = 24,
        item3 = 36
    } ]]

```

- apply/unpack
```lua
local rng = ranges.fromArray { 1, 2, 3 }
rng:apply(print)
print(rng:unpack())
-- both output: 1    2    3
```

- foreach
```lua
ranges.fromArray { 1, 2, 3 }:foreach(function(value, index)
    print(("%d: %d"):format(index, value))
end)
-- output:
--  1: 1
--  2: 2
--  3: 3
```

- aggregations
```lua
local rng = ranges.fromArray { 1, 2, 3 }
local min = rng:min() -- 1
local max = rng:max() -- 3
local sum = rng:sum() -- 6
local cnt = rng:count() -- 3
local agg = rng:aggregate(function(acc, value)
    return acc + value * value
end, 100) -- 114
local all_even = rng:all(function(value)
    return value % 2 == 0
end) -- false
local any_even = rng:any(function(value)
    return value % 2 == 0
end) -- true
local str = ranges.fromArray { 1, 2, 3 }
    :concat " + " -- "1 + 2 + 3"
```

- generaters
```lua
local a = ranges.rep(0, 5) -- { 0, 0, 0, 0, 0 }
local i = 0
local b = ranges.generate(function()
        i = i + 1
        return i * i
    end, 5)
    :toarray() -- { 1, 4, 9, 16, 25 }
```

- zip
```lua
local a = ranges.zip({ 1, 2, 3 }, { 4, 5, 6 })
    :toarray() --[[ {
         { 1, 4 },
         { 2, 5 },
         { 3, 6 },
    } ]]
```

- array to table / table to array
```lua
local a = ranges.fromArray { "a", "b", "c" }
    :select(function(value, index)
        return index, value
    end)
    :totable() --[[ {
        a = 1,
        b = 2,
        c = 3,
    } ]]
local b = ranges.fromTable(a)
    :iselect(function(key, value)
        return { key = key, value = value }
    end)
    :toarray() --[[ {
        { key = "a", value = 1 },
        { key = "b", value = 2 },
        { key = "c", value = 3 },
    } ]] -- with undefined order
```

- slice
```lua
local rng = ranges.fromArray { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
local first_3 = rng:take(3):toarray() -- { 1, 2, 3 }
local last_3 = rng:skip(7):toarray() -- { 8, 9, 10 }
local mid_3 = rng:skip(3):take(3):toarray() -- { 4, 5, 6 }
local chunks = rng:slice(3):toarray() --[[ {
        { 1, 2, 3 },
        { 4, 5, 6 },
        { 7, 8, 9 },
        { 10 },
    }]]
local chunks_no_tail = rng:slice(3, true):toarray() --[[ {
        { 1, 2, 3 },
        { 4, 5, 6 },
        { 7, 8, 9 },
    }]]
```

- table items
```lua
local rng = ranges.fromTable { a = 1, b = 2, c = 3 }
local items = rng:items():toarray() --[[
        { "a", 1 },
        { "b", 2 },
        { "c", 3 },
    ]]
local keys = rng:keys():toarray() -- { "a", "b", "c" }
local values = rng:values():toarray() -- { 1, 2, 3 }
-- all with undefined order
```

- iterators
```lua
for k, v in rng:iter() do
    print(k, v)
end
-- output:
-- 1    11
-- 2    22
-- 3    33
```
```lua
for k, v in rng:loopIter() do
    print(k, v)
end
-- output:
-- 1    11
-- 2    22
-- 3    33
-- 1    11
-- 2    22
-- 3    33
-- 1    11
-- 2    22
-- 3    33
-- (endless)
```