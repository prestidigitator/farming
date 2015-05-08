-- Constants

local UPDATE_TIME_META = "farming:update_time";

local SECS_PER_CYCLE   = nil;  -- Updated by GrowthModel.update() below


-- Utility Functions

--- Poisson distribution function.
 --
 -- @param lambda
 --    The distribution average.
 -- @param max
 --    The distribution maximum.
 -- @return
 --    A number between 0 and max (both inclusive).
 --
local function poisson(lambda, max)
   lambda, max = tonumber(lambda), tonumber(max);
   if not lambda or not max or lambda <= 0 or max < 1 then return 0; end;
   max = math.floor(max);

   local pdf = math.exp(-lambda);
   local cdf = pdf;
   local u   = math.random();

   if u < cdf then return 0; end;
   for i = 1, max - 1 do
      pdf = pdf * lambda / i;
      cdf = cdf + pdf;
      if u < cdf then return i; end;
   end;

   return max;
end;

local function clamp(x, min, max)
   return (x < min and min) or (x > max and max) or x;
end;

local function in_range(x, min, max)
   return min <= x and x <= max;
end;

--- Returns the number of seconds of daylight between two times.
 --
 -- @param time_game_1
 --    The first time, as reported by minetest.get_gametime().
 -- @param time_game_2
 --    The second time, as reported by minetest.get_gametime().
 -- @param time_day_2
 --    The second time (corresponding to time_game_2) as reported by
 --    minetest.get_timeofday().
 --
local function day_time(time_game_1, time_game_2, time_day_2)
   local time_day_1 = time_day_2 - (time_game_2 - time_game_1)/SECS_PER_CYCLE;

   -- since sunup, today
   local t1_c = time_day_1 - 0.25;
   local t2_c = time_day_2 - 0.25;

   local dt_c = clamp(t2_c, 0, 0.5) - clamp(t1_c, 0, 0.5);  -- today
   if t1_c < -0.5 then
      local nc = math.floor(-t1_c);
      dt_c = dt_c + 0.5*nc;
      t1_c = tc_1 + nc;
      dt_c = dt_c + clamp(-t1_c - 0.5, 0, 0.5);
   end;

   return dt_c * SECS_PER_CYCLE;
end;

local function night_time(time_game_1, time_game_2, time_day_2)
   local time_day_1 = time_day_2 - (time_game_2 - time_game_1)/SECS_PER_CYCLE;

   -- since last sundown
   local t1_c, t2_c;
   if time_game_2 < 0.75 then
      t1_c = time_day_1 + 0.25;
      t2_c = time_day_2 + 0.25;
   else
      t1_c = time_day_1 - 0.75;
      t2_c = time_day_2 - 0.75;
   end;

   local dt_c = clamp(t2_c, 0, 0.5) - clamp(t1_c, 0, 0.5);  -- tonight
   if t1_c < -0.5 then
      local nc = math.floor(-t1_c);
      dt_c = dt_c + 0.5*nc;
      t1_c = tc_1 + nc;
      dt_c = dt_c + clamp(-t1_c - 0.5, 0, 0.5);
   end;

   return dt_c * SECS_PER_CYCLE;
end;


-- API

GrowthModel           = {};
GrowthModel_meta      = {};
GrowthModel_inst_ops  = {};
GrowthModel_inst_meta = { __index = GrowthModel_inst_ops };

--- Creates a new growth model.
 --
 -- A different model can be used for each type of plant, or one global one can
 -- be used for all plants.
 --
 -- Called as: gm = GrowthModel(min_light, max_light, avg_secs_per_stage);
 --
 -- @param min_light
 --    The minimum light necessary for the plant to grow.
 -- @param max_light
 --    The maximum light allowed for the plant to grow (mushrooms might grow in
 --    the dark).
 -- @param avg_secs_per_stage
 --    Average number of seconds per stage of growth (in ideal conditions).
 --
local function GrowthModel_new(min_light, max_light, avg_secs_per_stage)
   -- defaults
   min_light          = tonumber(min_light)          or 13;
   max_light          = tonumber(max_light)          or 1000;
   avg_secs_per_stage = tonumber(avg_secs_per_stage) or 160;

   return setmetatable(
          {
             min_light          = min_light,
             max_light          = max_light,
             avg_secs_per_stage = avg_secs_per_stage,
          },
          GrowthModel_inst_meta);
end;
function GrowthModel_meta:__call(...) return GrowthModel_new(...); end;

--- Updates time information from minetest.conf settings.
 --
 -- Only call if you expect this to change while the server is running.
 --
function GrowthModel.update()
   local time_speed = tonumber(minetest.setting_get("time_speed")) or 72;
   SECS_PER_CYCLE = (time_speed > 0 and (24 * 60 * 60 / time_speed)) or nil;
end;

--- Marks a node as having had its growth evaluated, creating a basis for the
 -- next growth calculation.
 --
function GrowthModel_inst_ops:mark_time(pos)
   minetest.get_meta(pos):set_float(UPDATE_TIME_META, minetest.get_gametime());
end;

--- Determines how many stages to grow a plant.
 --
 -- The number of stages is determined by a Poisson distribution, with the
 -- average being the number of growth periods (with appropriate lighting) that
 -- have elapsed since the last call (note that the first call just marks the
 -- current time and does not do any growth).
 --
 -- @param pos
 --    The plant's position.
 -- @param stage
 --    The plant's current stage of growth.
 -- @param max_stage
 --    The plant's last stage of growth.
 --
function GrowthModel_inst_ops:growth_stages(pos, stage, max_stage)
   local meta = minetest.get_meta(pos);

   local t1_s = meta:get_float(UPDATE_TIME_META);
   local t2_s = minetest.get_gametime();

   if not t1_s or t1_s <= 0 or t2_s <= t1_s then return 0; end;

   local light_pos = { x = pos.x, y = pos.y + 1, z = pos.z };
   local dt_s = 0;
   if not SECS_PER_CYCLE then  -- Time is frozen
      local light = minetest.get_node_light(light_pos);
      if in_range(light, self.min_light, self.max_light) then
         dt_s = t2_s - t1_s;
      end;
   else
      local night_light = minetest.get_node_light(light_pos, 0);
      local day_light   = minetest.get_node_light(light_pos, 0.5);
      local grow_night  = in_range(night_light, self.min_light, self.max_light);
      local grow_day    = in_range(day_light,   self.min_light, self.max_light);

      if grow_day then
         if grow_night then
            dt_s = t2_s - t1_s;
         else
            dt_s = day_time(t1_s, t2_s, minetest.get_timeofday());
         end;
      elseif grow_night then
         dt_s = night_time(t1_s, t2_s, minetest.get_timeofday());
      end;
   end;
   if dt_s <= 0 then return 0; end;

   local avg_growth_periods = dt_s / self.avg_secs_per_stage;
   local max_growth_periods = max_stage - stage;

   return poisson(avg_growth_periods, max_growth_periods);
end;

setmetatable(GrowthModel, GrowthModel_meta);

GrowthModel.update();

return GrowthModel;
