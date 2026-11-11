library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_TX_tb is
end entity;

architecture sim of uart_TX_tb is
    constant clk_period : time := 10 ns;

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_ready : std_logic;
    signal tx_start : std_logic := '0';
    signal tx       : std_logic;
begin

    DUT : entity work.uart_TX
        generic map (CLKS_PER_BIT => 16)
        port map (
            clk      => clk,
            rst_n    => rst_n,
            tx_ready => tx_ready,
            tx_start => tx_start,
            tx_data  => tx_data,
            tx       => tx
        );

    clk <= not clk after clk_period / 2;

    stimulus : process
    begin
        rst_n    <= '0';
        tx_start <= '0';
        wait for 4 * clk_period;
        rst_n <= '1';
        wait until rising_edge(clk);

        for i in 0 to 5 loop
            -- wait until the transmitter is idle
            wait until rising_edge(clk) and tx_ready = '1';

            -- present data and a one-clock start pulse
            tx_data  <= std_logic_vector(to_unsigned(65 + i, 8));  -- 'A', 'B', ...
            tx_start <= '1';
            wait until rising_edge(clk);   -- DUT samples start and data here
            tx_start <= '0';
        end loop;

        -- let the last frame finish
        wait until rising_edge(clk) and tx_ready = '1';
        wait for 5 * clk_period;

        report "Simulation finished" severity note;
        wait;  -- stop the process
    end process;

end architecture;