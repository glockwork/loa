-------------------------------------------------------------------------------
-- Title      : Commutation control via Hall sensors
-- Project    : 
-------------------------------------------------------------------------------
-- File       : commutation.vhd
-- Author     : Fabian Greif  <fabian.greif@rwth-aachen.de>
-- Company    : Roboterclub Aachen e.V.
-- Created    : 2011-12-17
-- Last update: 2011-12-18
-- Platform   : Spartan 3
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.motor_control_pkg.all;

package commutation_pkg is

  type hall_sensor_type is record
    ha : std_logic;  -- Channel A -> Phase U magnetic field detection
    hb : std_logic;  -- Channel B -> Phase V magnetic field detection
    hc : std_logic;  -- Channel C -> Phase W magnetic field detection
  end record;
  
  type bldc_driver_stage_type is record
    u : half_bridge_type;               -- Channel 1 (U,X)
    v : half_bridge_type;               -- Channel 2 (V,Y)
    w : half_bridge_type;               -- Channel 3 (W,Z)
  end record;

  component commutation
    port (
      driver_stage_p : out bldc_driver_stage_type;
      
      hall_p         : in  hall_sensor_type;
      pwm_p          : in  half_bridge_type;
      sd_p           : in  std_logic;

      clk            : in  std_logic);
  end component;
  
end commutation_pkg;

-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.commutation_pkg.all;
use work.motor_control_pkg.all;

entity commutation is
  
  port (
    driver_stage_p : out bldc_driver_stage_type;  -- Driver Stage of 3 half bridges

    hall_p : in hall_sensor_type;       -- Hall Sensors
    pwm_p  : in half_bridge_type;
    sd_p   : in std_logic;              -- Shutdown

    clk : in std_logic
    );
end commutation;

architecture behavioral of commutation is
  type commutation_type is record
    hall_1r : std_logic_vector(2 downto 0);
    hall_2r : std_logic_vector(2 downto 0);

    driver : bldc_driver_stage_type;
  end record;

  signal r, rin : commutation_type;
begin
  seq_proc : process(clk)
  begin
    if rising_edge(clk) then
--      if reset = '1' then
--        r.state <= idle;
--      else
      r <= rin;
--      end if;
    end if;
  end process seq_proc;

  comb_proc : process(r, hall_p, pwm_p, sd_p)
    variable v : commutation_type;
  begin
    v := r;

    -- synchronise Hall sensors inputs
    v.hall_1r := hall_p.ha & hall_p.hb & hall_p.hc;
    v.hall_2r := r.hall_1r;

    case r.hall_2r is
      when "101" =>
        v.driver :=
          (u => (pwm_p.high, pwm_p.low),
           v => (pwm_p.low, pwm_p.high),
           w => ('0', '0'));
      when "100" =>
        v.driver :=
          (u => (pwm_p.high, pwm_p.low),
           v => ('0', '0'),
           w => (pwm_p.low, pwm_p.high));
      when "110" =>
        v.driver :=
          (u => ('0', '0'),
           v => (pwm_p.high, pwm_p.low),
           w => (pwm_p.low, pwm_p.high));
      when "010" =>
        v.driver :=
          (u => (pwm_p.low, pwm_p.high),
           v => (pwm_p.high, pwm_p.low),
           w => ('0', '0'));
      when "011" =>
        v.driver :=
          (u => (pwm_p.low, pwm_p.high),
           v => ('0', '0'),
           w => (pwm_p.high, pwm_p.low));
      when "001" =>
        v.driver :=
          (u => ('0', '0'),
           v => (pwm_p.low, pwm_p.high),
           w => (pwm_p.high, pwm_p.low));

      when others =>
        -- Error in the readings of the Hall-Sensors
        -- Disable PWM
        v.driver :=
          (u => ('0', '0'),
           v => ('0', '0'),
           w => ('0', '0'));
    end case;

    if sd_p = '1' then
      v.driver :=
        (u => ('0', '0'),
         v => ('0', '0'),
         w => ('0', '0'));
    end if;

    rin <= v;
  end process comb_proc;

  driver_stage_p <= r.driver;

  -- Component instantiations
end behavioral;