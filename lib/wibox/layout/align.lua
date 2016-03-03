---------------------------------------------------------------------------
-- @author Uli Schlachter
-- @copyright 2010 Uli Schlachter
-- @release @AWESOME_VERSION@
-- @classmod wibox.layout.align
---------------------------------------------------------------------------

local table = table
local pairs = pairs
local type = type
local floor = math.floor
local util = require("awful.util")
local base = require("wibox.widget.base")

local align = {}

--- Calculate the layout of an align layout.
-- @param context The context in which we are drawn.
-- @param width The available width.
-- @param height The available height.
function align:layout(context, width, height)
    local result = {}

    -- Draw will have to deal with all three align modes and should work in a
    -- way that makes sense if one or two of the widgets are missing (if they
    -- are all missing, it won't draw anything.) It should also handle the case
    -- where the fit something that isn't set to expand (for instance the
    -- outside widgets when the expand mode is "inside" or any of the widgets
    -- when the expand mode is "none" wants to take up more space than is
    -- allowed.
    local size_first = 0
    -- start with all the space given by the parent, subtract as we go along
    local size_remains = self.dir == "y" and height or width
    -- This is only set & used if expand ~= "inside" and we have second width.
    -- It contains the size allocated to the second widget.
    local size_second

    -- we will prioritize the middle widget unless the expand mode is "inside"
    --  if it is, we prioritize the first widget by not doing this block also,
    --  if the second widget doesn't exist, we will prioritise the first one
    --  instead
    if self._expand ~= "inside" and self.second then
        local w, h = base.fit_widget(self, context, self.second, width, height)
        size_second = self.dir == "y" and h or w
        -- if all the space is taken, skip the rest, and draw just the middle
        -- widget
        if size_second >= size_remains then
            return { base.place_widget_at(self.second, 0, 0, width, height) }
        else
            -- the middle widget is sized first, the outside widgets are given
            --  the remaining space if available we will draw later
            size_remains = floor((size_remains - size_second) / 2)
        end
    end
    if self.first then
        local w, h, _ = width, height, nil
        -- we use the fit function for the "inside" and "none" modes, but
        --  ignore it for the "outside" mode, which will force it to expand
        --  into the remaining space
        if self._expand ~= "outside" then
            if self.dir == "y" then
                _, h = base.fit_widget(self, context, self.first, width, size_remains)
                size_first = h
                -- for "inside", the third widget will get a chance to use the
                --  remaining space, then the middle widget. For "none" we give
                --  the third widget the remaining space if there was no second
                --  widget to take up any space (as the first if block is skipped
                --  if this is the case)
                if self._expand == "inside" or not self.second then
                    size_remains = size_remains - h
                end
            else
                w, _ = base.fit_widget(self, context, self.first, size_remains, height)
                size_first = w
                if self._expand == "inside" or not self.second then
                    size_remains = size_remains - w
                end
            end
        else
            if self.dir == "y" then
                h = size_remains
            else
                w = size_remains
            end
        end
        table.insert(result, base.place_widget_at(self.first, 0, 0, w, h))
    end
    -- size_remains will be <= 0 if first used all the space
    if self.third and size_remains > 0 then
        local w, h, _ = width, height, nil
        if self._expand ~= "outside" then
            if self.dir == "y" then
                _, h = base.fit_widget(self, context, self.third, width, size_remains)
                -- give the middle widget the rest of the space for "inside" mode
                if self._expand == "inside" then
                    size_remains = size_remains - h
                end
            else
                w, _ = base.fit_widget(self, context, self.third, size_remains, height)
                if self._expand == "inside" then
                    size_remains = size_remains - w
                end
            end
        else
            if self.dir == "y" then
                h = size_remains
            else
                w = size_remains
            end
        end
        local x, y = width - w, height - h
        table.insert(result, base.place_widget_at(self.third, x, y, w, h))
    end
    -- here we either draw the second widget in the space set aside for it
    -- in the beginning, or in the remaining space, if it is "inside"
    if self.second and size_remains > 0 then
        local x, y, w, h = 0, 0, width, height
        if self._expand == "inside" then
            if self.dir == "y" then
                h = size_remains
                x, y = 0, size_first
            else
                w = size_remains
                x, y = size_first, 0
            end
        else
            local _
            if self.dir == "y" then
                _, h = base.fit_widget(self, context, self.second, width, size_second)
                y = floor( (height - h)/2 )
            else
                w, _ = base.fit_widget(self, context, self.second, size_second, height)
                x = floor( (width -w)/2 )
            end
        end
        table.insert(result, base.place_widget_at(self.second, x, y, w, h))
    end
    return result
end

--- Set the layout's first widget. This is the widget that is at the left/top
function align:set_first(widget)
    if self.first == widget then
        return
    end
    self.first = widget
    self:emit_signal("widget::layout_changed")
end

--- Set the layout's second widget. This is the centered one.
function align:set_second(widget)
    if self.second == widget then
        return
    end
    self.second = widget
    self:emit_signal("widget::layout_changed")
end

--- Set the layout's third widget. This is the widget that is at the right/bottom
function align:set_third(widget)
    if self.third == widget then
        return
    end
    self.third = widget
    self:emit_signal("widget::layout_changed")
end

--- Get all children of this layout
-- @treturn table a list of all widgets
function align:get_children()
    return util.from_sparse {self.first, self.second, self.third}
end

--- Replace the layout children
-- This layout only accept three children, all others will be ignored
-- @tparam table children A table composed of valid widgets
function align:set_children(children)
    self:set_first(children[1])
    self:set_second(children[2])
    self:set_third(children[3])
end

--- Fit the align layout into the given space. The align layout will
-- ask for the sum of the sizes of its sub-widgets in its direction
-- and the largest sized sub widget in the other direction.
-- @param context The context in which we are fit.
-- @param orig_width The available width.
-- @param orig_height The available height.
function align:fit(context, orig_width, orig_height)
    local used_in_dir = 0
    local used_in_other = 0

    for _, v in pairs{self.first, self.second, self.third} do
        local w, h = base.fit_widget(self, context, v, orig_width, orig_height)

        local max = self.dir == "y" and w or h
        if max > used_in_other then
            used_in_other = max
        end

        used_in_dir = used_in_dir + (self.dir == "y" and h or w)
    end

    if self.dir == "y" then
        return used_in_other, used_in_dir
    end
    return used_in_dir, used_in_other
end

--- Set the expand mode which determines how sub widgets expand to take up
-- unused space.
--
-- @tparam[opt=inside] string mode How to use unused space.
--
-- * "inside" - Default option. Size of outside widgets is determined using
--   their fit function. Second, middle, or center widget expands to fill
--   remaining space.
-- * "outside" - Center widget is sized using its fit function and placed in
--   the center of the allowed space. Outside widgets expand (or contract) to
--   fill remaining space on their side.
-- * "none" - All widgets are sized using their fit function, drawn to only the
--   returned space, or remaining space, whichever is smaller. Center widget
--   gets priority.
function align:set_expand(mode)
    if mode == "none" or mode == "outside" then
        self._expand = mode
    else
        self._expand = "inside"
    end
    self:emit_signal("widget::layout_changed")
end

function align:reset()
    for _, v in pairs({ "first", "second", "third" }) do
        self[v] = nil
    end
    self:emit_signal("widget::layout_changed")
end

local function get_layout(dir, first, second, third)
    local ret = base.make_widget()
    ret.dir = dir

    for k, v in pairs(align) do
        if type(v) == "function" then
            ret[k] = v
        end
    end

    ret:set_expand("inside")
    ret:set_first(first)
    ret:set_second(second)
    ret:set_third(third)

    -- An align layout allow set_children to have empty entries
    ret.allow_empty_widget = true

    return ret
end

--- Returns a new horizontal align layout. An align layout can display up to
-- three widgets. The widget set via :set_left() is left-aligned. :set_right()
-- sets a widget which will be right-aligned. The remaining space between those
-- two will be given to the widget set via :set_middle().
-- @tparam[opt] widget left Widget to be put to the left.
-- @tparam[opt] widget middle Widget to be put to the middle.
-- @tparam[opt] widget right Widget to be put to the right.
function align.horizontal(left, middle, right)
    local ret = get_layout("x", left, middle, right)

    ret.set_left = ret.set_first
    ret.set_middle = ret.set_second
    ret.set_right = ret.set_third

    return ret
end

--- Returns a new vertical align layout. An align layout can display up to
-- three widgets. The widget set via :set_top() is top-aligned. :set_bottom()
-- sets a widget which will be bottom-aligned. The remaining space between those
-- two will be given to the widget set via :set_middle().
-- @tparam[opt] widget top Widget to be put to the top.
-- @tparam[opt] widget middle Widget to be put to the middle.
-- @tparam[opt] widget bottom Widget to be put to the right.
function align.vertical(top, middle, bottom)
    local ret = get_layout("y", top, middle, bottom)

    ret.set_top = ret.set_first
    ret.set_middle = ret.set_second
    ret.set_bottom = ret.set_third

    return ret
end

return align

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80