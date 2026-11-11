library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_loopback_tb is
end entity;

architecture sim of uart_loopback_tb is
    constant clk_period   : time    := 10 ns;
    constant CLKS_PER_BIT : natural := 16;
    constant N_BYTES      : natural := 6;

    type byte_array_t is array (0 to N_BYTES-1) of std_logic_vector(7 downto 0);
    constant TEST_DATA : byte_array_t := (x"41", x"42", x"55", x"AA", x"00", x"FF");

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';

    -- TX side
    signal tx_start : std_logic := '0';
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_ready : std_logic;

    -- serial line
    signal line     : std_logic;

    -- RX side
    signal rx_ready : std_logic;
    signal rx_valid : std_logic;
    signal rx_data  : std_logic_vector(7 downto 0);

    signal all_sent     : boolean := false;
    signal rx_count     : natural := 0;
    signal error_count  : natural := 0;
begin

    clk <= not clk after clk_period / 2;

    TX_DUT : entity work.uart_TX
        generic map (CLKS_PER_BIT => CLKS_PER_BIT)
        port map (
            clk      => clk,
            rst_n    => rst_n,
            tx_ready => tx_ready,
            tx_start => tx_start,
            tx_data  => tx_data,
            tx       => line
        );

    RX_DUT : entity work.uart_RX
        generic map (CLKS_PER_BIT => CLKS_PER_BIT)
        port map (
            clk      => clk,
            rst_n    => rst_n,
            rx_ready => rx_ready,
            rx_valid => rx_valid,
            rx_data  => rx_data,
            rx       => line
        );

    -- Stimulus: send each byte when the transmitter is idle
    stimulus : process
    begin
        rst_n    <= '0';
        tx_start <= '0';
        wait for 4 * clk_period;
        rst_n <= '1';
        wait until rising_edge(clk);

        for i in 0 to N_BYTES-1 loop
            wait until rising_edge(clk) and tx_ready = '1';
            tx_data  <= TEST_DATA(i);
            tx_start <= '1';
            wait until rising_edge(clk);   -- DUT samples start and data here
            tx_start <= '0';
        end loop;

        all_sent <= true;
        wait;
    end process;

    -- Checker: compare each received byte with the expected one
    checker : process(clk)
    begin
        if rising_edge(clk) then
            if rx_valid = '1' then
                if rx_count < N_BYTES then
                    if rx_data = TEST_DATA(rx_count) then
                        report "RX byte " & integer'image(rx_count) &
                               " OK: 0x" & integer'image(to_integer(unsigned(rx_data)))
                               severity note;
                    else
                        report "RX byte " & integer'image(rx_count) &
                               " MISMATCH: got " & integer'image(to_integer(unsigned(rx_data))) &
                               ", expected " & integer'image(to_integer(unsigned(TEST_DATA(rx_count))))
                               severity error;
                        error_count <= error_count + 1;
                    end if;
                end if;
                rx_count <= rx_count + 1;
            end if;
        end if;
    end process;

    -- End of simulation: wait for the last frame, then report the result
    finish : process
    begin
        wait until all_sent;
        wait until rising_edge(clk) and tx_ready = '1';   -- last frame done
        wait for 5 * CLKS_PER_BIT * clk_period;           -- allow RX to finish

        assert rx_count = N_BYTES
            report "Expected " & integer'image(N_BYTES) & " bytes, received " &
                   integer'image(rx_count)
            severity error;

        if rx_count = N_BYTES and error_count = 0 then
            report "TEST PASSED: all bytes received correctly" severity note;
        else
            report "TEST FAILED" severity error;
        end if;
        wait;
    end process;

end architecture;